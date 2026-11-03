// ignore: fcheck_dead_code
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/git_file_status.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

part 'git_service.git_status.dart';
part 'git_service.git_commit.dart';
part 'git_service.git_diff_stats.dart';
part 'git_service.git_exception.dart';
part 'git_service.git_porcelain.dart';

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

  /// The revision of the index (staged content), as `git show` names it:
  /// an empty name.
  static const String indexRevision = '';

  /// Version [version] reports when git runs but its output can't be
  /// parsed.
  static const String unknownVersion = 'Unknown';

  /// What a tracked file's changes compare against: HEAD, or the index
  /// before the first commit, when there is no HEAD.
  static const List<List<String>> _headBases = [
    ['HEAD'],
    ['--cached'],
  ];

  /// `git diff --no-index` exit code meaning "the files differ".
  static const int _noIndexDiffFoundExitCode = 1;

  /// The porcelain suffix of a wholly new directory.
  static const String _directorySuffix = '/';

  /// Runs `git` with [args] in [path] and returns its result when it
  /// exits 0.
  ///
  /// Throws a [GitException] with git's stderr when it fails, or the
  /// error when it can't be started.
  Future<ProcessResult> _runChecked(String path, List<String> args) async {
    final command = 'git ${args.join(' ')}';
    final ProcessResult result;
    try {
      result = await _runner.run('git', args, workingDirectory: path);
    } catch (e) {
      throw GitException(command, '$e');
    }
    if (result.exitCode != 0) {
      throw GitException(command, '${result.stderr}');
    }
    return result;
  }

  /// Runs a mutating `git` command with [args] in [path].
  ///
  /// Throws a [GitException] when git fails.
  Future<void> _mutate(String path, List<String> args) async {
    await _runChecked(path, args);
  }

  /// The repository-relative paths of every file below [dirPath], itself
  /// relative to [projectPath].
  Future<List<String>> _expandDirectoryToFiles(
    String projectPath,
    String dirPath,
  ) async {
    final files = await _entries.listFiles(p.join(projectPath, dirPath));
    return [for (final file in files) p.relative(file, from: projectPath)];
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
  /// Throws a [GitException] when git fails.
  Future<GitStatus> getStatus(String path) async {
    final result = await _runChecked(path, ['status', '--porcelain']);
    final status = GitStatus(staged: [], unstaged: [], untracked: []);
    for (final entry in GitPorcelain.parseStatus(result.stdout.toString())) {
      // Porcelain reports a wholly new directory as `dir/`; list its files
      final files = entry.path.endsWith(_directorySuffix)
          ? await _expandDirectoryToFiles(
              path,
              entry.path.substring(
                0,
                entry.path.length - _directorySuffix.length,
              ),
            )
          : [entry.path];
      for (final file in files) {
        GitPorcelain.classify(entry.code, file, status);
      }
    }
    return status;
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
  /// diff, so a cut diff still names every staged file; empty when nothing
  /// is staged.
  ///
  /// Throws a [GitException] when git fails.
  Future<String> getStagedDiff(String path) async {
    final output = StringBuffer();
    for (final args in [
      ['diff', '--cached', '--stat'],
      ['diff', '--cached'],
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
      final command = 'git ${args.join(' ')}';
      final ProcessResult result;
      try {
        result = await _runner.run('git', [
          ...args,
          filePath,
        ], workingDirectory: path);
      } catch (e) {
        throw GitException(command, '$e');
      }
      if (result.exitCode != _noIndexDiffFoundExitCode) {
        throw GitException(command, '${result.stderr}');
      }
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

  /// Returns the committed content of the absolute [filePath] at HEAD, or an
  /// empty string when the file isn't in HEAD (new or untracked).
  Future<String> getHeadContent(String filePath) async {
    return await _showRelativeToFile(filePath, headRevision) ?? '';
  }

  /// Returns the staged (index) content of the absolute [filePath], or null
  /// when the file isn't in the index.
  Future<String?> getStagedContent(String filePath) {
    return _showRelativeToFile(filePath, indexRevision);
  }

  /// Returns the raw bytes of the absolute [filePath] at [revision],
  /// [indexRevision] for the staged copy, or null when it isn't there:
  /// for binary files such as images, which [getHeadContent] would mangle.
  Future<Uint8List?> getBytesAt(
    String filePath, {
    String revision = headRevision,
  }) {
    return _runner.bytesOf('git', [
      'show',
      _showSpec(filePath, revision),
    ], workingDirectory: p.dirname(filePath));
  }

  /// Runs `git show <revision>:./<name>` from the file's own directory, so
  /// the path resolves correctly wherever the repository root is.
  Future<String?> _showRelativeToFile(String filePath, String revision) {
    return _runner.outputOf('git', [
      'show',
      _showSpec(filePath, revision),
    ], workingDirectory: p.dirname(filePath));
  }

  /// The `git show` object name of [filePath] at [revision], relative to
  /// the file's own directory.
  static String _showSpec(String filePath, String revision) =>
      '$revision:./${p.basename(filePath)}';

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
  /// as wholly added.
  Future<
    ({Map<String, GitDiffStats> staged, Map<String, GitDiffStats> unstaged})
  >
  getChangeStats(String projectPath, GitStatus status) async {
    final staged = await _numstat(projectPath, cached: true);
    final unstaged = await _numstat(projectPath, cached: false);
    for (final file in status.untracked) {
      unstaged[file] = await _newFileStats(p.join(projectPath, file));
    }
    return (staged: staged, unstaged: unstaged);
  }

  /// Parses `git diff --numstat` of the index ([cached]) or the working
  /// copy into line counts per file; empty when git fails.
  Future<Map<String, GitDiffStats>> _numstat(
    String path, {
    required bool cached,
  }) async {
    final output = await _runner.outputOf('git', [
      'diff',
      if (cached) '--cached',
      '--numstat',
      '--no-renames',
    ], workingDirectory: path);
    return GitDiffStats.parseNumstat(output ?? '');
  }

  /// Counts every line of the untracked file at [filePath] as added; zero
  /// lines when it is missing, too big to load or binary, as
  /// `git diff --numstat` counts binary files.
  Future<GitDiffStats> _newFileStats(String filePath) async {
    if (!_entries.exists(filePath)) return _wholeNewFile(0);
    final String? content;
    try {
      content = await _reader.tryRead(filePath);
    } on FileSystemException {
      // Not UTF-8 text, such as an image
      return _wholeNewFile(0);
    }
    if (content == null) return _wholeNewFile(0);
    return _wholeNewFile(content.split('\n').length);
  }

  /// Line counts of a file not in HEAD with [added] lines.
  static GitDiffStats _wholeNewFile(int added) =>
      GitDiffStats(added: added, removed: 0, isNewFile: true);

  /// Added/removed line counts of [filePath] against HEAD (staged and
  /// unstaged changes together, as [getFileDiff] shows them); an untracked
  /// file counts as wholly added. Zero when git fails.
  Future<GitDiffStats> getFileDiffStats(String path, String filePath) async {
    try {
      if (!await _isTracked(path, filePath)) {
        return await _newFileStats(filePath);
      }
      for (final base in _headBases) {
        final output = await _runner.outputOf('git', [
          'diff',
          ...base,
          '--numstat',
          '--no-renames',
          '--',
          filePath,
        ], workingDirectory: path);
        if (output == null) continue;
        return GitDiffStats.parseNumstat(output).values.firstOrNull ??
            _noChanges;
      }
    } catch (_) {
      // Counted as unchanged below
    }
    return _noChanges;
  }

  /// Line counts of a tracked file without changes.
  static GitDiffStats get _noChanges =>
      GitDiffStats(added: 0, removed: 0, isNewFile: false);

  /// The two sides of the change to the absolute [filePath] since HEAD:
  /// its committed content (empty when it isn't in HEAD) and [newText], or
  /// without it the staged content when [staged], else the working copy.
  /// Null when the file isn't in a Git repository.
  Future<({String oldText, String newText})?> diffAgainstHead(
    String filePath, {
    String? newText,
    bool staged = false,
  }) async {
    if (!await isGitRepository(p.dirname(filePath))) return null;
    final oldText = await getHeadContent(filePath);
    final stagedText = staged ? await getStagedContent(filePath) : null;
    return (
      oldText: oldText,
      newText: newText ?? stagedText ?? await _readWorkingCopy(filePath),
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
