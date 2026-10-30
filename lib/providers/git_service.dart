// ignore: fcheck_dead_code
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:path/path.dart' as p;

part 'git_service.git_status.dart';
part 'git_service.git_commit.dart';
part 'git_service.git_diff_stats.dart';
part 'git_service.git_exception.dart';

/// Represents `GitService`.
class GitService {
  final ProcessRunner _runner;

  /// Creates a Git service that launches commands through [_runner].
  const GitService([this._runner = const ProcessRunner()]);

  /// Fields of `git rev-list --left-right --count`: ahead, then behind.
  static const int _syncCountFields = 2;

  /// Tab-separated fields of `git diff --numstat`: added, removed, path.
  static const int _numstatFields = 3;

  /// Tab-separated fields of a [getRecentCommits] line: hash, time, subject.
  static const int _commitFields = 3;

  /// Porcelain separator between the old and new path of a rename or copy.
  static const String _renameArrow = ' -> ';

  /// `git diff --no-index` exit code meaning "the files differ".
  static const int _noIndexDiffFoundExitCode = 1;

  /// Runs a mutating Git command and returns [successMessage].
  ///
  /// Throws a [GitException] carrying [failureMessage] when git fails or
  /// can't be started.
  Future<String> _runGitMutation({
    required String path,
    required List<String> args,
    required String successMessage,
    required String failureMessage,
  }) async {
    final ProcessResult result;
    try {
      result = await _runner.run('git', args, workingDirectory: path);
    } catch (e) {
      throw GitException(failureMessage, '$e');
    }
    if (result.exitCode != 0) {
      throw GitException(failureMessage, '${result.stderr}');
    }
    return successMessage;
  }

  /// Files the porcelain entry for [file] with two-letter [status] into the
  /// staged, unstaged and untracked lists of [into].
  static void _classify(String status, String file, GitStatus into) {
    if (status[0] == '?') {
      into.untracked.add(file);
      return;
    }
    if (status[0] != ' ') {
      into.staged.add(file);
      into.stagedKinds[file] = _kindOf(status[0]);
    }
    if (status[1] != ' ') {
      into.unstaged.add(file);
      into.unstagedKinds[file] = _kindOf(status[1]);
    }
  }

  /// The change a porcelain status letter stands for: added, deleted, or
  /// modified for everything else (edits, renames, type changes, conflicts).
  static GitFileStatus _kindOf(String letter) => switch (letter) {
    'A' => GitFileStatus.added,
    'D' => GitFileStatus.deleted,
    _ => GitFileStatus.modified,
  };

  // Expand directory to all contained files
  Future<List<String>> _expandDirectoryToFiles(
    String projectPath,
    String dirPath,
  ) async {
    final files = <String>[];
    final dir = Directory('$projectPath/$dirPath');

    if (await dir.exists()) {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          // Get relative path from project root
          final relativePath = p.relative(entity.path, from: projectPath);
          files.add(relativePath);
        }
      }
    }

    return files;
  }

  /// Installed Git version (e.g. `2.39.3`); null when Git isn't available,
  /// `Unknown` when its version output can't be parsed.
  Future<String?> version() async {
    final output = await _runner.outputOf('git', [
      '--version',
    ], runInShell: true);
    if (output == null) return null;
    return RegExp(r'git version (\d+\.\d+\.\d+)')
            .firstMatch(output)
            ?.group(1) ??
        'Unknown';
  }

  /// Returns true if the provided path is inside a valid Git repository.
  Future<bool> isGitRepository(String path) {
    return _runner.succeeds('git', [
      'rev-parse',
      '--git-dir',
    ], workingDirectory: path);
  }

  /// Initializes a new Git repository at the provided path.
  Future<String> initRepository(String path) async {
    return _runGitMutation(
      path: path,
      args: ['init'],
      successMessage: 'Git repository initialized successfully',
      failureMessage: 'Failed to initialize Git repository',
    );
  }

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
    final ProcessResult result;
    try {
      result = await _runner.run('git', [
        'status',
        '--porcelain',
      ], workingDirectory: path);
    } catch (e) {
      throw GitException('Failed to get Git status', '$e');
    }
    if (result.exitCode != 0) {
      throw GitException('Failed to get Git status', '${result.stderr}');
    }

    final status = GitStatus(staged: [], unstaged: [], untracked: []);
    final lines = result.stdout
        .toString()
        .split('\n')
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      if (line.length < AppMetric.gitStatusFieldOffset) continue;
      final code = line.substring(0, AppMetric.doubleLineLimit);
      // A rename or copy lists `old -> new`; the change lives at the new path
      final entryPath = line.substring(AppMetric.gitStatusFieldOffset);
      final file = entryPath.contains(_renameArrow)
          ? entryPath.split(_renameArrow).last
          : entryPath;

      // Porcelain reports a wholly new directory as `dir/`; list its files
      final files = file.endsWith('/')
          ? await _expandDirectoryToFiles(
              path,
              file.substring(0, file.length - 1),
            )
          : [file];
      for (final entry in files) {
        _classify(code, entry, status);
      }
    }
    return status;
  }

  /// Stages the provided file paths.
  Future<String> stageFiles(String path, List<String> files) async {
    return _runGitMutation(
      path: path,
      args: ['add', ...files],
      successMessage: 'Files staged successfully',
      failureMessage: 'Failed to stage files',
    );
  }

  /// Unstages the provided file paths from the index.
  Future<String> unstageFiles(String path, List<String> files) async {
    return _runGitMutation(
      path: path,
      args: ['reset', 'HEAD', ...files],
      successMessage: 'Files unstaged successfully',
      failureMessage: 'Failed to unstage files',
    );
  }

  /// Creates a commit with the given commit message.
  Future<String> commit(String path, String message) async {
    return _runGitMutation(
      path: path,
      args: ['commit', '-m', message],
      successMessage: 'Changes committed successfully',
      failureMessage: 'Failed to commit changes',
    );
  }

  /// Rewrites the last commit with the staged changes; keeps its message
  /// when [message] is empty.
  Future<String> amend(String path, String message) async {
    return _runGitMutation(
      path: path,
      args: [
        'commit',
        '--amend',
        ...message.isEmpty ? ['--no-edit'] : ['-m', message],
      ],
      successMessage: 'Last commit amended successfully',
      failureMessage: 'Failed to amend last commit',
    );
  }

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
    final counts = output?.trim().split(RegExp(r'\s+'));
    if (counts == null || counts.length != _syncCountFields) {
      return (ahead: 0, behind: 0);
    }
    return (
      ahead: int.tryParse(counts.first) ?? 0,
      behind: int.tryParse(counts.last) ?? 0,
    );
  }

  /// Pushes local commits to the configured remote.
  Future<String> push(String path) async {
    return _runGitMutation(
      path: path,
      args: ['push'],
      successMessage: 'Changes pushed successfully',
      failureMessage: 'Failed to push changes',
    );
  }

  /// Pulls remote changes into the current branch.
  Future<String> pull(String path) async {
    return _runGitMutation(
      path: path,
      args: ['pull'],
      successMessage: 'Changes pulled successfully',
      failureMessage: 'Failed to pull changes',
    );
  }

  /// Returns the current checked-out branch name, if available.
  Future<String?> getCurrentBranch(String path) async {
    try {
      final result = await _runner.run('git', [
        'branch',
        '--show-current',
      ], workingDirectory: path);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Returns a summary of the staged changes followed by their unified
  /// diff, so a cut diff still names every staged file; empty when nothing
  /// is staged.
  ///
  /// Throws a [GitException] when git fails.
  Future<String> getStagedDiff(String path) async {
    const failure = 'Failed to get staged diff';
    final output = StringBuffer();
    for (final args in [
      ['diff', '--cached', '--stat'],
      ['diff', '--cached'],
    ]) {
      final result = await _runner.run('git', args, workingDirectory: path);
      if (result.exitCode != 0) {
        throw GitException(failure, '${result.stderr}');
      }
      output.writeln(result.stdout.toString().trim());
    }
    return output.toString().trim();
  }

  /// Returns up to [count] recent commits, newest first, each with its date
  /// and whether it still waits to be pushed.
  Future<List<GitCommit>> getRecentCommits(
    String path, {
    int count = AppMetric.gitCommitDefaultCount,
  }) async {
    try {
      final result = await _runner.run('git', [
        'log',
        '--format=%H%x09%ct%x09%s',
        '-n',
        count.toString(),
      ], workingDirectory: path);
      if (result.exitCode == 0) {
        final unpushed = await _unpushedHashes(path);
        final lines = result.stdout
            .toString()
            .split('\n')
            .where((line) => line.isNotEmpty);
        return [for (final line in lines) ?_parseCommit(line, unpushed)];
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
  }

  /// Parses a `hash<TAB>unix time<TAB>subject` log [line]; null when it
  /// doesn't have that shape.
  static GitCommit? _parseCommit(String line, Set<String> unpushed) {
    final fields = line.split('\t');
    if (fields.length < _commitFields) return null;
    final seconds = int.tryParse(fields[1]);
    if (seconds == null) return null;
    final hash = fields.first;
    return GitCommit(
      hash: hash,
      // A subject may itself hold tabs
      message: fields.skip(_commitFields - 1).join('\t'),
      date: DateTime.fromMillisecondsSinceEpoch(
        seconds * Duration.millisecondsPerSecond,
      ),
      isUnpushed: unpushed.contains(hash),
    );
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
    const failure = 'Failed to get diff';
    try {
      if (!await _isTracked(path, filePath)) {
        final result = await _runner.run('git', [
          'diff',
          '--no-index',
          '--',
          '/dev/null',
          filePath,
        ], workingDirectory: path);
        if (result.exitCode != _noIndexDiffFoundExitCode) {
          throw GitException(failure, '${result.stderr}');
        }
        return result.stdout.toString();
      }

      // Before the first commit there is no HEAD; the index is the base
      for (final base in [
        ['HEAD'],
        ['--cached'],
      ]) {
        final result = await _runner.run('git', [
          'diff',
          ...base,
          '--',
          filePath,
        ], workingDirectory: path);
        if (result.exitCode == 0) return result.stdout.toString();
      }
      throw const GitException(failure);
    } on GitException {
      rethrow;
    } catch (e) {
      throw GitException(failure, '$e');
    }
  }

  /// Returns the committed content of the absolute [filePath] at HEAD, or an
  /// empty string when the file isn't in HEAD (new or untracked).
  Future<String> getHeadContent(String filePath) async {
    return await _showRelativeToFile(filePath, 'HEAD') ?? '';
  }

  /// Returns the staged (index) content of the absolute [filePath], or null
  /// when the file isn't in the index.
  Future<String?> getStagedContent(String filePath) {
    return _showRelativeToFile(filePath, '');
  }

  /// Runs `git show <revision>:./<name>` from the file's own directory, so
  /// the path resolves correctly wherever the repository root is.
  Future<String?> _showRelativeToFile(String filePath, String revision) async {
    try {
      final result = await _runner.run('git', [
        'show',
        '$revision:./${p.basename(filePath)}',
      ], workingDirectory: p.dirname(filePath));
      return result.exitCode == 0 ? result.stdout.toString() : null;
    } catch (_) {
      return null;
    }
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

  /// Discards local changes for tracked files and removes untracked files.
  ///
  /// Throws a [GitException] when git fails.
  Future<String> discardChanges(String path, List<String> files) async {
    const failure = 'Failed to discard changes';
    try {
      final untrackedFiles = <String>[];
      final modifiedFiles = <String>[];
      for (final file in files) {
        (await _isTracked(path, file) ? modifiedFiles : untrackedFiles).add(
          file,
        );
      }

      if (modifiedFiles.isNotEmpty) {
        await _runGitMutation(
          path: path,
          args: ['checkout', '--', ...modifiedFiles],
          successMessage: '',
          failureMessage: failure,
        );
      }

      for (final file in untrackedFiles) {
        final fileEntity = File('$path/$file');
        if (await fileEntity.exists()) {
          await fileEntity.delete();
        }
      }

      return 'Changes discarded successfully';
    } on GitException {
      rethrow;
    } catch (e) {
      throw GitException(failure, '$e');
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
      unstaged[file] = await _newFileStats(File(p.join(projectPath, file)));
    }
    return (staged: staged, unstaged: unstaged);
  }

  /// Parses `git diff --numstat` of the index ([cached]) or the working
  /// copy into line counts per file; empty when git fails. Binary files
  /// count as zero lines.
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
    final stats = <String, GitDiffStats>{};
    for (final line in (output ?? '').split('\n')) {
      final fields = line.split('\t');
      if (fields.length < _numstatFields) continue;
      stats[fields.skip(_numstatFields - 1).join('\t')] = GitDiffStats(
        added: int.tryParse(fields[0]) ?? 0,
        removed: int.tryParse(fields[1]) ?? 0,
        isNewFile: false,
      );
    }
    return stats;
  }

  /// Counts every line of the untracked [file] as added; zero lines when it
  /// is missing or too big to load.
  static Future<GitDiffStats> _newFileStats(File file) async {
    if (!await file.exists()) {
      return GitDiffStats(added: 0, removed: 0, isNewFile: true);
    }
    final content = await FileSystemItem.fileToStringMaxSizeCheck(file);
    if (content == FileSystemItem.fileTooBigMessage) {
      return GitDiffStats(added: 0, removed: 0, isNewFile: true);
    }
    return GitDiffStats(
      added: content.split('\n').length,
      removed: 0,
      isNewFile: true,
    );
  }

  /// Returns added/removed line counts for a file.
  Future<GitDiffStats> getFileDiffStats(String path, String filePath) async {
    try {
      // First check if file is tracked
      final isTracked = await _isTracked(path, filePath);

      if (!isTracked) return await _newFileStats(File(filePath));

      // For tracked files, get diff stats
      final result = await _runner.run('git', [
        'diff',
        '--numstat',
        '--',
        filePath,
      ], workingDirectory: path);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isEmpty) {
          // No changes
          return GitDiffStats(added: 0, removed: 0, isNewFile: false);
        }

        final parts = output.split('\t');
        if (parts.length >= AppMetric.doubleLineLimit) {
          final added = int.tryParse(parts[0]) ?? 0;
          final removed = int.tryParse(parts[1]) ?? 0;
          return GitDiffStats(added: added, removed: removed, isNewFile: false);
        }
      }

      // Fallback: parse diff output
      final diffResult = await _runner.run('git', [
        'diff',
        '--',
        filePath,
      ], workingDirectory: path);

      if (diffResult.exitCode == 0) {
        final diff = diffResult.stdout.toString();
        int added = 0;
        int removed = 0;

        final lines = diff.split('\n');
        for (final line in lines) {
          if (line.startsWith('+') && !line.startsWith('+++')) {
            added++;
          } else if (line.startsWith('-') && !line.startsWith('---')) {
            removed++;
          }
        }

        return GitDiffStats(added: added, removed: removed, isNewFile: false);
      }

      return GitDiffStats(added: 0, removed: 0, isNewFile: false);
    } catch (e) {
      return GitDiffStats(added: 0, removed: 0, isNewFile: false);
    }
  }
}
