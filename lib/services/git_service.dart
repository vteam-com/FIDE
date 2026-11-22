// ignore: fcheck_dead_code
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_stamp.dart';
import 'package:fide/models/git_file_status.dart';
import 'package:fide/models/tool_version.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

part 'git_service.git_status.dart';
part 'git_service.git_commit.dart';
part 'git_service.git_diff_stats.dart';
part 'git_service.git_exception.dart';
part 'git_service.git_head_changes.dart';
part 'git_service.git_porcelain.dart';
part 'git_service.git_repo_location.dart';

/// Runs Git on a repository: reads its status, diffs and history, and
/// stages, commits, syncs and discards changes.
///
/// Mutations return nothing and throw a [GitException] with git's stderr;
/// the callers word what the user sees. Output parsing lives in
/// [GitPorcelain]; the working copy is read through the injected
/// [FileContentReader] and [FileEntryService].
class GitService {
  final ProcessRunner _runner;
  final FileContentReader _reader;
  final FileEntryService _entries;

  /// Creates a Git service that launches commands through [_runner] and
  /// reads the working copy with [reader] and [entries].
  const GitService(
    this._runner, {
    this._reader = const FileContentReader(),
    this._entries = const FileEntryService(),
  });

  /// The revision of the last commit, as `git show` names it.
  static const String headRevision = 'HEAD';

  /// What a tracked file's changes compare against: HEAD, or the index
  /// before the first commit, when there is no HEAD.
  static const List<List<String>> _headBases = [
    ['HEAD'],
    ['--cached'],
  ];

  /// `git diff --no-index` exit code meaning "the files differ".
  static const int _noIndexDiffFoundExitCode = 1;

  /// The suffix git gives a wholly untracked directory it lists.
  static const String _directorySuffix = '/';

  /// The separator of `-z` output records.
  static const String _nul = '\x00';

  /// The variable naming the index file git reads and writes.
  static const String _indexFileVariable = 'GIT_INDEX_FILE';

  /// Name of the temporary folder holding the copy of the index that
  /// [_movesIn] pairs moves in.
  static const String _movesIndexFolder = 'fide_git_moves_';

  /// The pathspec of the whole repository, wherever git runs in it.
  static const String _wholeRepository = ':/';

  /// Line counts of untracked files already read, by absolute path, with
  /// the modification time and size they were read at: a reload reads
  /// only the files that changed since.
  static final Map<String, ({FileStamp stamp, int lines})> _lineCounts = {};

  /// Runs `git` with [args] in [path] and returns its result when it
  /// exits with [expectedExitCode].
  ///
  /// Throws a [GitException] naming [command] (by default the whole
  /// command) with git's stderr when it fails, or the error when it can't
  /// be started.
  Future<ProcessResult> _runChecked(
    String path,
    List<String> args, {
    String? command,
    int expectedExitCode = 0,
  }) async {
    final name = command ?? 'git ${args.join(' ')}';
    try {
      return await _runner.runChecked(
        'git',
        args,
        workingDirectory: path,
        expectedExitCode: expectedExitCode,
        error: (result) => GitException(name, '${result.stderr}'),
      );
    } on GitException {
      rethrow;
    } catch (e) {
      throw GitException(name, '$e');
    }
  }

  /// Runs a mutating `git` command with [args] in [path].
  ///
  /// Throws a [GitException] when git fails.
  Future<void> _mutate(String path, List<String> args) async {
    await _runChecked(path, args);
  }

  /// Installed Git version (e.g. `2.39.3`); null when Git isn't available,
  /// [unknownVersion] when its version output can't be parsed.
  Future<String?> version() async {
    final output = await _runner.outputOf('git', [
      '--version',
    ], runInShell: true);
    if (output == null) return null;
    return GitPorcelain.parseVersion(output) ?? unknownVersion;
  }

  /// Returns true if the provided path is inside a valid Git repository.
  Future<bool> isGitRepository(String path) {
    return _runner.succeeds('git', [
      'rev-parse',
      '--git-dir',
    ], workingDirectory: path);
  }

  /// Initializes a new Git repository at [path].
  ///
  /// Throws a [GitException] when git fails.
  Future<void> initRepository(String path) => _mutate(path, ['init']);

  /// Initializes a repository at [path] and commits everything in it; true
  /// only when init, add and commit all succeed within the Git timeout.
  Future<bool> initWithInitialCommit(String path) async {
    const steps = [
      ['init'],
      ['add', '.'],
      ['commit', '-m', 'Initial commit'],
    ];
    for (final args in steps) {
      final succeeded = await _runner
          .succeeds('git', args, workingDirectory: path)
          .timeout(AppDuration.gitOperationTimeout, onTimeout: () => false);
      if (!succeeded) return false;
    }
    return true;
  }

  /// Reads Git porcelain status and groups files into staged/unstaged/untracked.
  ///
  /// A wholly new folder's files are listed one by one, as git would add
  /// them: git walks the folder itself, leaving out what `.gitignore`
  /// ignores, such as a new package's `build/` and `.dart_tool/`.
  ///
  /// A file moved without git, deleted at one path and untracked at
  /// another, is one unstaged rename when git finds the two alike, as it
  /// does once both are staged.
  ///
  /// Throws a [GitException] when git fails.
  Future<GitStatus> getStatus(String path) async {
    final result = await _runChecked(path, [
      'status',
      '--porcelain',
      '--untracked-files=all',
    ]);
    final status = GitStatus(staged: [], unstaged: [], untracked: []);
    for (final entry in GitPorcelain.parseStatus(result.stdout.toString())) {
      GitPorcelain.classify(
        entry.code,
        entry.path,
        status,
        movedFrom: entry.movedFrom,
      );
    }
    if (status.mayHaveMoves) {
      for (final MapEntry(key: to, value: stats) in (await _movesIn(
        path,
      )).entries) {
        status.addMove(stats.movedFrom!, to);
      }
    }
    return status;
  }

  /// The files of the work tree of the repository at [path] git pairs as
  /// moved, with their line counts, by new path: a deleted file and an
  /// untracked one alike, compared with the index, or with [base] such as
  /// `HEAD` when given. Empty when git fails or the index can't be copied.
  ///
  /// Git only pairs files it tracks, so it runs on a copy of the index
  /// where the untracked files are added intent-to-add, which records no
  /// content and leaves the real index as it is.
  Future<Map<String, GitDiffStats>> _movesIn(
    String path, {
    List<String> base = const [],
  }) async {
    final index = await _runner.outputOf('git', [
      'rev-parse',
      '--git-path',
      'index',
    ], workingDirectory: path);
    if (index == null) return const {};
    final indexFile = File(p.join(path, index.trim()));
    if (!indexFile.existsSync()) return const {};
    Directory? folder;
    try {
      folder = await Directory.systemTemp.createTemp(_movesIndexFolder);
      final copy = await indexFile.copy(p.join(folder.path, 'index'));
      final environment = {_indexFileVariable: copy.path};
      final added = await _runner.outputOf(
        'git',
        ['add', '--intent-to-add', '--ignore-removal', _wholeRepository],
        workingDirectory: path,
        environment: environment,
      );
      if (added == null) return const {};
      final output = await _runner.outputOf(
        'git',
        ['diff', ...base, '-M', '--numstat', '-z'],
        workingDirectory: path,
        environment: environment,
      );
      return {
        for (final MapEntry(key: file, value: stats)
            in GitDiffStats.parseNumstat(
              output ?? '',
              recordSeparator: _nul,
            ).entries)
          if (stats.movedFrom != null) file: stats,
      };
    } on FileSystemException {
      // Moves are a bonus: without a copy of the index, none are paired
      return const {};
    } finally {
      try {
        await folder?.delete(recursive: true);
      } on FileSystemException {
        // Left for the system to clear with its other temporary files
      }
    }
  }

  /// Stages [files].
  ///
  /// Throws a [GitException] when git fails.
  Future<void> stageFiles(String path, List<String> files) =>
      _mutate(path, ['add', ...files]);

  /// Unstages [files] from the index.
  ///
  /// Throws a [GitException] when git fails.
  Future<void> unstageFiles(String path, List<String> files) =>
      _mutate(path, ['reset', 'HEAD', ...files]);

  /// Creates a commit with [message].
  ///
  /// Throws a [GitException] when git fails.
  Future<void> commit(String path, String message) =>
      _mutate(path, ['commit', '-m', message]);

  /// Rewrites the last commit with the staged changes; keeps its message
  /// when [message] is empty.
  ///
  /// Throws a [GitException] when git fails.
  Future<void> amend(String path, String message) => _mutate(path, [
    'commit',
    '--amend',
    ...message.isEmpty ? ['--no-edit'] : ['-m', message],
  ]);

  /// Whether the last commit can be amended safely: HEAD exists and no
  /// remote-tracking branch contains it yet (it has not been pushed).
  Future<bool> canAmend(String path) async {
    final remoteBranches = await _runner.outputOf('git', [
      'branch',
      '--remotes',
      '--contains',
      'HEAD',
    ], workingDirectory: path);
    return remoteBranches != null && remoteBranches.trim().isEmpty;
  }

  /// Updates the remote-tracking branches so [syncCounts] sees new remote
  /// commits; true when the fetch succeeds.
  Future<bool> fetch(String path) {
    return _runner.succeeds('git', [
      'fetch',
      '--quiet',
    ], workingDirectory: path);
  }

  /// Commits the current branch has that its upstream lacks ([ahead], to
  /// push) and the reverse ([behind], to pull), as of the last [fetch].
  /// Both are zero when the branch has no upstream.
  Future<({int ahead, int behind})> syncCounts(String path) async {
    final output = await _runner.outputOf('git', [
      'rev-list',
      '--left-right',
      '--count',
      'HEAD...@{upstream}',
    ], workingDirectory: path);
    return GitPorcelain.parseSyncCounts(output);
  }

  /// Pushes local commits to the configured remote.
  ///
  /// Throws a [GitException] when git fails.
  Future<void> push(String path) => _mutate(path, ['push']);

  /// Pulls remote changes into the current branch.
  ///
  /// Throws a [GitException] when git fails.
  Future<void> pull(String path) => _mutate(path, ['pull']);

  /// Returns the current checked-out branch name, if available.
  Future<String?> getCurrentBranch(String path) async {
    final output = await _runner.outputOf('git', [
      'branch',
      '--show-current',
    ], workingDirectory: path);
    return output?.trim();
  }

  /// Returns a summary of the staged changes followed by their unified
  /// diff, a moved file shown as renamed, so a cut diff still names every
  /// staged file; empty when nothing is staged.
  ///
  /// Throws a [GitException] when git fails.
  Future<String> getStagedDiff(String path) async {
    final output = StringBuffer();
    for (final args in [
      ['diff', '--cached', '-M', '--stat'],
      ['diff', '--cached', '-M'],
    ]) {
      final result = await _runChecked(path, args);
      output.writeln(result.stdout.toString().trim());
    }
    return output.toString().trim();
  }

  /// Returns up to [count] recent commits, newest first, each with its date
  /// and whether it still waits to be pushed; empty when git fails.
  Future<List<GitCommit>> getRecentCommits(
    String path, {
    int count = AppMetric.gitCommitDefaultCount,
  }) async {
    final output = await _runner.outputOf('git', [
      'log',
      '--format=%H%x09%ct%x09%s',
      '-n',
      count.toString(),
    ], workingDirectory: path);
    if (output == null) return [];
    final unpushed = await _unpushedHashes(path);
    return [
      for (final line in output.split('\n'))
        if (line.isNotEmpty) ?GitPorcelain.parseCommit(line, unpushed),
    ];
  }

  /// Full hashes of the commits the upstream branch lacks; empty when the
  /// branch has no upstream.
  Future<Set<String>> _unpushedHashes(String path) async {
    final output = await _runner.outputOf('git', [
      'rev-list',
      '@{upstream}..HEAD',
    ], workingDirectory: path);
    return (output ?? '').split('\n').where((h) => h.isNotEmpty).toSet();
  }

  /// Returns the unified diff of [filePath] against HEAD (staged and
  /// unstaged changes together); untracked files diff as wholly added.
  /// Empty when the file has no changes.
  ///
  /// Throws a [GitException] when git fails.
  Future<String> getFileDiff(String path, String filePath) async {
    if (!await _isTracked(path, filePath)) {
      const args = ['diff', '--no-index', '--', '/dev/null'];
      final result = await _runChecked(
        path,
        [...args, filePath],
        command: 'git ${args.join(' ')}',
        expectedExitCode: _noIndexDiffFoundExitCode,
      );
      return result.stdout.toString();
    }

    for (final base in _headBases) {
      final output = await _runner.outputOf('git', [
        'diff',
        ...base,
        '--',
        filePath,
      ], workingDirectory: path);
      if (output != null) return output;
    }
    throw const GitException('git diff');
  }

  /// Returns the committed content of the absolute [filePath] at HEAD, or
  /// for a file moved since, staged or not, that of the file it moved
  /// from; an empty string when it isn't in HEAD (new or untracked).
  Future<String> getHeadContent(String filePath) async {
    return await _showAtHead(filePath, _runner.outputOf) ?? '';
  }

  /// Returns the raw bytes of the absolute [filePath] at HEAD, or of the
  /// file it moved from, as [getHeadContent] reads them; null when it
  /// isn't there: for binary files such as images, which [getHeadContent]
  /// would mangle.
  Future<Uint8List?> getHeadBytes(String filePath) {
    return _showAtHead(filePath, _runner.bytesOf);
  }

  /// What [show] collects of `git show` of the absolute [filePath] at
  /// HEAD, run from the file's own directory so the path resolves wherever
  /// the repository root is; when the file isn't in HEAD, of the file it
  /// moved from, run from the root. Null when neither is there.
  Future<T?> _showAtHead<T>(
    String filePath,
    Future<T?> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    })
    show,
  ) async {
    final own = await show('git', [
      'show',
      '$headRevision:./${p.basename(filePath)}',
    ], workingDirectory: p.dirname(filePath));
    if (own != null) return own;
    final location = await repoLocation(p.dirname(filePath));
    if (location == null) return null;
    final String? headPath;
    try {
      headPath = (await getStatus(location.root))
          .headPathOf(location.pathOf(p.basename(filePath)));
    } on GitException {
      return null;
    }
    if (headPath == null) return null;
    return show('git', [
      'show',
      '$headRevision:$headPath',
    ], workingDirectory: location.root);
  }

  /// Whether [file] is tracked in the repository at [path].
  ///
  /// Deliberately not [ProcessRunner.succeeds]: when git can't run this
  /// throws, so [discardChanges] never mistakes every file for an untracked
  /// one and deletes it.
  Future<bool> _isTracked(String path, String file) async {
    final result = await _runner.run('git', [
      'ls-files',
      '--error-unmatch',
      file,
    ], workingDirectory: path);
    return result.exitCode == 0;
  }

  /// Discards local changes for tracked [files] and removes untracked ones.
  ///
  /// Throws a [GitException] when git fails or can't run.
  Future<void> discardChanges(String path, List<String> files) async {
    const command = 'git ls-files';
    final untrackedFiles = <String>[];
    final modifiedFiles = <String>[];
    try {
      for (final file in files) {
        (await _isTracked(path, file) ? modifiedFiles : untrackedFiles).add(
          file,
        );
      }
    } catch (e) {
      throw GitException(command, '$e');
    }

    if (modifiedFiles.isNotEmpty) {
      await _mutate(path, ['checkout', '--', ...modifiedFiles]);
    }

    for (final file in untrackedFiles) {
      final filePath = p.join(path, file);
      if (_entries.exists(filePath)) {
        await _entries.delete(filePath, isDirectory: false);
      }
    }
  }

  /// Added/removed line counts of every changed file in [status], keyed by
  /// repository-relative path: [staged] compares the index to HEAD,
  /// [unstaged] the working copy to the index, with untracked files counted
  /// as wholly added. A renamed file, staged or not, counts the lines
  /// changed since the file it moved from.
  Future<
    ({Map<String, GitDiffStats> staged, Map<String, GitDiffStats> unstaged})
  >
  getChangeStats(String projectPath, GitStatus status) async {
    final staged = await _numstat(projectPath, cached: true);
    final unstaged = await _numstat(projectPath, cached: false);
    for (final file in status.untracked) {
      unstaged[file] = await _newFileStats(p.join(projectPath, file));
    }
    if (status.unstagedMovedFrom.isNotEmpty) {
      unstaged.addAll(await _movesIn(projectPath));
    }
    return (staged: staged, unstaged: unstaged);
  }

  /// Parses `git diff --numstat` of the index ([cached]) or the working
  /// copy into line counts per file, a rename's at its new path; empty
  /// when git fails.
  Future<Map<String, GitDiffStats>> _numstat(
    String path, {
    required bool cached,
  }) async {
    final output = await _runner.outputOf('git', [
      'diff',
      if (cached) '--cached',
      '--numstat',
      '-z',
    ], workingDirectory: path);
    return GitDiffStats.parseNumstat(output ?? '', recordSeparator: _nul);
  }

  /// Counts every line of the untracked file at [filePath] as added; zero
  /// lines when it is missing, too big to load or binary, as
  /// `git diff --numstat` counts binary files.
  ///
  /// A file unchanged since it was last counted (same modification time and
  /// size) isn't read again.
  Future<GitDiffStats> _newFileStats(String filePath) async {
    final stat = await File(filePath).stat();
    if (stat.type != FileSystemEntityType.file) return _wholeNewFile(0);
    final cached = _lineCounts[filePath];
    if (cached != null && cached.stamp == stat.stamp) {
      return _wholeNewFile(cached.lines);
    }
    final lines = await _countLines(filePath);
    if (_lineCounts.length >= AppMetric.gitLineCountCacheLimit) {
      _lineCounts.clear();
    }
    _lineCounts[filePath] = (stamp: stat.stamp, lines: lines);
    return _wholeNewFile(lines);
  }

  /// Lines of the text file at [filePath]; zero when it is too big to load
  /// or isn't text.
  Future<int> _countLines(String filePath) async {
    try {
      return (await _reader.tryRead(filePath))?.split('\n').length ?? 0;
    } on FileSystemException {
      // Not UTF-8 text, such as an image
      return 0;
    }
  }

  /// Line counts of a file not in HEAD with [added] lines.
  static GitDiffStats _wholeNewFile(int added) =>
      GitDiffStats(added: added, removed: 0, isNewFile: true);

  /// Added/removed line counts of the absolute [filePath] against HEAD
  /// (staged and unstaged changes together, as [getFileDiff] shows them);
  /// an untracked file counts as wholly added. Null outside a repository.
  ///
  /// Reads the whole repository's changes: to count several files, read
  /// [repoLocation] and [headChanges] once and ask [diffStatsIn].
  Future<GitDiffStats?> getFileDiffStats(String filePath) async {
    final location = await repoLocation(p.dirname(filePath));
    if (location == null) return null;
    return diffStatsIn(await headChanges(location.root), location, filePath);
  }

  /// Where the folder [path] sits in its repository; null when it isn't
  /// in one.
  Future<GitRepoLocation?> repoLocation(String path) async {
    final output = await _runner.outputOf('git', [
      'rev-parse',
      '--show-toplevel',
      '--show-prefix',
    ], workingDirectory: path);
    return switch (output?.split('\n')) {
      [final root, final prefix, ...] => GitRepoLocation(
        root: root,
        prefix: prefix,
      ),
      _ => null,
    };
  }

  /// The changes of the working copy of the repository at [root] against
  /// HEAD, for every file at once; nothing changed when git fails.
  Future<GitHeadChanges> headChanges(String root) async {
    final untracked = await _runner.outputOf('git', [
      'ls-files',
      '--others',
      '--directory',
      '-z',
    ], workingDirectory: root);
    for (final base in _headBases) {
      final output = await _runner.outputOf('git', [
        'diff',
        ...base,
        '--numstat',
        '-z',
      ], workingDirectory: root);
      if (output == null) continue;
      final stats = GitDiffStats.parseNumstat(output, recordSeparator: _nul);
      final untrackedPaths = _records(untracked);
      // A file moved without git: deleted at one path, untracked at another
      if (untrackedPaths.isNotEmpty && stats.values.any((s) => s.mayBeGone)) {
        stats.addAll(await _movesIn(root, base: base));
      }
      return GitHeadChanges(stats: stats, untracked: untrackedPaths);
    }
    return GitHeadChanges(stats: const {}, untracked: _records(untracked));
  }

  /// The non-empty records of `-z` [output].
  static Set<String> _records(String? output) =>
      (output ?? '').split(_nul).where((record) => record.isNotEmpty).toSet();

  /// Added/removed line counts against HEAD of the absolute [filePath],
  /// in the folder at [location], from its repository's [changes]; an
  /// untracked file counts as wholly added, unless git pairs it with the
  /// file it moved from.
  Future<GitDiffStats> diffStatsIn(
    GitHeadChanges changes,
    GitRepoLocation location,
    String filePath,
  ) async {
    final repoPath = location.pathOf(p.basename(filePath));
    final stats = changes.stats[repoPath];
    if (stats?.movedFrom == null && changes.isUntracked(repoPath)) {
      return _newFileStats(filePath);
    }
    return stats ?? _noChanges;
  }

  /// Line counts of a tracked file without changes.
  static GitDiffStats get _noChanges =>
      GitDiffStats(added: 0, removed: 0, isNewFile: false);

  /// The two sides of the change to the absolute [filePath] since HEAD:
  /// its committed content (empty when it isn't in HEAD) and [newText], or
  /// without it the working copy. Null when the file isn't in a Git
  /// repository.
  Future<({String oldText, String newText})?> diffAgainstHead(
    String filePath, {
    String? newText,
  }) async {
    if (!await isGitRepository(p.dirname(filePath))) return null;
    return (
      oldText: await getHeadContent(filePath),
      newText: newText ?? await _readWorkingCopy(filePath),
    );
  }

  /// The working-copy content of [filePath], or '' when it is missing or
  /// unreadable.
  Future<String> _readWorkingCopy(String filePath) async {
    if (!_entries.exists(filePath)) return '';
    try {
      return await _reader.read(filePath);
    } on FileSystemException {
      return '';
    }
  }
}
