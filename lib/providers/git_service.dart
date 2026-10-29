// ignore: fcheck_dead_code
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:path/path.dart' as path;

part 'git_service.git_status.dart';
part 'git_service.git_commit.dart';
part 'git_service.git_diff_stats.dart';
part 'git_service.git_exception.dart';

/// Represents `GitService`.
class GitService {
  final ProcessRunner _runner;

  /// Creates a Git service that launches commands through [_runner].
  const GitService([this._runner = const ProcessRunner()]);

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
    if (status[0] != ' ') {
      into.staged.add(file);
    }
    if (status[1] != ' ') {
      if (status[0] == ' ' && status[1] == '?') {
        into.untracked.add(file);
      } else {
        into.unstaged.add(file);
      }
    }
  }

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
          final relativePath = path.relative(entity.path, from: projectPath);
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
      final file = line.substring(AppMetric.gitStatusFieldOffset);

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

  /// Returns recent commits up to [count] in one-line format.
  Future<List<GitCommit>> getRecentCommits(
    String path, {
    int count = AppMetric.gitCommitDefaultCount,
  }) async {
    try {
      final result = await _runner.run('git', [
        'log',
        '--oneline',
        '-n',
        count.toString(),
      ], workingDirectory: path);
      if (result.exitCode == 0) {
        final lines = result.stdout
            .toString()
            .split('\n')
            .where((line) => line.isNotEmpty);
        return lines.map((line) {
          final firstSpaceIndex = line.indexOf(' ');
          final hash = firstSpaceIndex > 0
              ? line.substring(0, firstSpaceIndex)
              : line;
          final message = firstSpaceIndex > 0
              ? line.substring(firstSpaceIndex + 1)
              : '';
          return GitCommit(hash: hash, message: message);
        }).toList();
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
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
        '$revision:./${path.basename(filePath)}',
      ], workingDirectory: path.dirname(filePath));
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

  /// Returns added/removed line counts for a file.
  Future<GitDiffStats> getFileDiffStats(String path, String filePath) async {
    try {
      // First check if file is tracked
      final isTracked = await _isTracked(path, filePath);

      if (!isTracked) {
        // For untracked files, count all lines as additions
        final file = File(filePath);
        if (await file.exists()) {
          final content = await FileSystemItem.fileToStringMaxSizeCheck(file);
          if (content == FileSystemItem.fileTooBigMessage) {
            return GitDiffStats(added: 0, removed: 0, isNewFile: true);
          }
          final lines = content.split('\n');
          return GitDiffStats(added: lines.length, removed: 0, isNewFile: true);
        }
        return GitDiffStats(added: 0, removed: 0, isNewFile: true);
      }

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
