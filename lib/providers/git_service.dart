// ignore: fcheck_dead_code
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:path/path.dart' as path;

part 'git_service.git_status.dart';
part 'git_service.git_commit.dart';
part 'git_service.git_diff_stats.dart';

/// Represents `GitService`.
class GitService {
  static final GitService _instance = GitService._internal();
  factory GitService() => _instance;
  GitService._internal();

  /// Runs a mutating Git command and returns a normalized status message.
  Future<String> _runGitFileMutation({
    required String path,
    required List<String> args,
    required String successMessage,
    required String failurePrefix,
    required String errorPrefix,
  }) async {
    try {
      final result = await Process.run('git', args, workingDirectory: path);
      if (result.exitCode == 0) {
        return successMessage;
      }
      return '$failurePrefix: ${result.stderr}';
    } catch (e) {
      return '$errorPrefix: $e';
    }
  }

  Future<String> _runGitDiff({
    required String path,
    required List<String> args,
    required String errorPrefix,
  }) async {
    try {
      final result = await Process.run('git', args, workingDirectory: path);
      return result.exitCode == 0 ? result.stdout.toString() : '';
    } catch (e) {
      return '$errorPrefix: $e';
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

  // Check if Git is available
  /// Returns true when the `git` executable is available on the system.
  Future<bool> isGitAvailable() async {
    try {
      final result = await Process.run('git', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  // Check if directory is a Git repository
  /// Returns true if the provided path is inside a valid Git repository.
  Future<bool> isGitRepository(String path) async {
    try {
      final result = await Process.run('git', [
        'rev-parse',
        '--git-dir',
      ], workingDirectory: path);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  // Initialize Git repository
  /// Initializes a new Git repository at the provided path.
  Future<String> initRepository(String path) async {
    try {
      final result = await Process.run('git', ['init'], workingDirectory: path);
      if (result.exitCode == 0) {
        return 'Git repository initialized successfully';
      } else {
        return 'Failed to initialize Git repository: ${result.stderr}';
      }
    } catch (e) {
      return 'Error initializing Git repository: $e';
    }
  }

  // Get Git status
  /// Reads Git porcelain status and groups files into staged/unstaged/untracked.
  Future<GitStatus> getStatus(String path) async {
    try {
      final result = await Process.run('git', [
        'status',
        '--porcelain',
      ], workingDirectory: path);
      if (result.exitCode == 0) {
        final lines = result.stdout
            .toString()
            .split('\n')
            .where((line) => line.isNotEmpty);
        final staged = <String>[];
        final unstaged = <String>[];
        final untracked = <String>[];

        for (final line in lines) {
          if (line.length < AppMetric.gitStatusFieldOffset) continue;
          final status = line.substring(0, AppMetric.doubleLineLimit);
          final file = line.substring(AppMetric.gitStatusFieldOffset);

          // Check if file path ends with / (directory) and expand it
          final isDirectory = file.endsWith('/');
          if (isDirectory) {
            // Expand directory to all contained files
            final dirFiles = await _expandDirectoryToFiles(
              path,
              file.substring(0, file.length - 1),
            );
            for (final dirFile in dirFiles) {
              if (status[0] != ' ') {
                staged.add(dirFile);
              }
              if (status[1] != ' ') {
                if (status[0] == ' ' && status[1] == '?') {
                  untracked.add(dirFile);
                } else {
                  unstaged.add(dirFile);
                }
              }
            }
          } else {
            // Regular file
            if (status[0] != ' ') {
              staged.add(file);
            }
            if (status[1] != ' ') {
              if (status[0] == ' ' && status[1] == '?') {
                untracked.add(file);
              } else {
                unstaged.add(file);
              }
            }
          }
        }

        return GitStatus(
          staged: staged,
          unstaged: unstaged,
          untracked: untracked,
        );
      } else {
        throw Exception('Failed to get Git status: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Error getting Git status: $e');
    }
  }

  // Stage files
  /// Stages the provided file paths.
  Future<String> stageFiles(String path, List<String> files) async {
    return _runGitFileMutation(
      path: path,
      args: ['add', ...files],
      successMessage: 'Files staged successfully',
      failurePrefix: 'Failed to stage files',
      errorPrefix: 'Error staging files',
    );
  }

  // Unstage files
  /// Unstages the provided file paths from the index.
  Future<String> unstageFiles(String path, List<String> files) async {
    return _runGitFileMutation(
      path: path,
      args: ['reset', 'HEAD', ...files],
      successMessage: 'Files unstaged successfully',
      failurePrefix: 'Failed to unstage files',
      errorPrefix: 'Error unstaging files',
    );
  }

  // Commit changes
  /// Creates a commit with the given commit message.
  Future<String> commit(String path, String message) async {
    try {
      final result = await Process.run('git', [
        'commit',
        '-m',
        message,
      ], workingDirectory: path);
      if (result.exitCode == 0) {
        return 'Changes committed successfully';
      } else {
        return 'Failed to commit changes: ${result.stderr}';
      }
    } catch (e) {
      return 'Error committing changes: $e';
    }
  }

  // Push to remote
  /// Pushes local commits to the configured remote.
  Future<String> push(String path) async {
    try {
      final result = await Process.run('git', ['push'], workingDirectory: path);
      if (result.exitCode == 0) {
        return 'Changes pushed successfully';
      } else {
        return 'Failed to push changes: ${result.stderr}';
      }
    } catch (e) {
      return 'Error pushing changes: $e';
    }
  }

  // Pull from remote
  /// Pulls remote changes into the current branch.
  Future<String> pull(String path) async {
    try {
      final result = await Process.run('git', ['pull'], workingDirectory: path);
      if (result.exitCode == 0) {
        return 'Changes pulled successfully';
      } else {
        return 'Failed to pull changes: ${result.stderr}';
      }
    } catch (e) {
      return 'Error pulling changes: $e';
    }
  }

  // Get current branch
  /// Returns the current checked-out branch name, if available.
  Future<String?> getCurrentBranch(String path) async {
    try {
      final result = await Process.run('git', [
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

  // Get recent commits
  /// Returns recent commits up to [count] in one-line format.
  Future<List<GitCommit>> getRecentCommits(
    String path, {
    int count = AppMetric.gitCommitDefaultCount,
  }) async {
    try {
      final result = await Process.run('git', [
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

  // Get diff for a specific file
  /// Returns a unified diff for one file, including new/untracked fallbacks.
  Future<String> getFileDiff(String path, String filePath) async {
    try {
      final result = await Process.run('git', [
        'diff',
        '--no-index',
        '--',
        '/dev/null',
        filePath,
      ], workingDirectory: path);

      // If the file is new/untracked, git diff --no-index will show it as added
      if (result.exitCode == 0 || result.exitCode == 1) {
        return result.stdout.toString();
      }

      // Try staged diff
      final stagedResult = await Process.run('git', [
        'diff',
        '--cached',
        '--',
        filePath,
      ], workingDirectory: path);

      if (stagedResult.exitCode == 0) {
        return stagedResult.stdout.toString();
      }

      // Try unstaged diff
      final unstagedResult = await Process.run('git', [
        'diff',
        '--',
        filePath,
      ], workingDirectory: path);

      if (unstagedResult.exitCode == 0) {
        return unstagedResult.stdout.toString();
      }

      // If no diff found, check if file is new
      final file = File(filePath);
      if (await file.exists()) {
        final String content = await FileSystemItem.fileToStringMaxSizeCheck(
          file,
        );
        if (content == FileSystemItem.fileTooBigMessage) {
          return content;
        }
        final lines = content.split('\n');
        final diffLines = <String>[];
        diffLines.add('diff --git a/$filePath b/$filePath');
        diffLines.add('new file mode 100644');
        diffLines.add('index 0000000..0000000');
        diffLines.add('--- /dev/null');
        diffLines.add('+++ b/$filePath');
        for (int i = 0; i < lines.length; i++) {
          diffLines.add('@@ -0,0 +${i + 1},1 @@');
          diffLines.add('+${lines[i]}');
        }
        return diffLines.join('\n');
      }

      return '';
    } catch (e) {
      return 'Error getting diff: $e';
    }
  }

  // Get diff for staged files
  /// Returns staged diff output for a file.
  Future<String> getStagedDiff(String path, String filePath) async {
    return _runGitDiff(
      path: path,
      args: ['diff', '--cached', '--', filePath],
      errorPrefix: 'Error getting staged diff',
    );
  }

  // Get diff for unstaged files
  /// Returns unstaged diff output for a file.
  Future<String> getUnstagedDiff(String path, String filePath) async {
    return _runGitDiff(
      path: path,
      args: ['diff', '--', filePath],
      errorPrefix: 'Error getting unstaged diff',
    );
  }

  // Get file content at a specific revision
  /// Returns file content resolved from a specific Git revision.
  Future<String> getFileContentAtRevision(
    String path,
    String filePath,
    String revision,
  ) async {
    try {
      final result = await Process.run('git', [
        'show',
        '$revision:$filePath',
      ], workingDirectory: path);

      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        throw Exception('Failed to get file content: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Error getting file content at revision: $e');
    }
  }

  // Discard changes for files (git checkout -- files or git rm for untracked)
  /// Discards local changes for tracked files and removes untracked files.
  Future<String> discardChanges(String path, List<String> files) async {
    try {
      final untrackedFiles = <String>[];
      final modifiedFiles = <String>[];

      // Check each file individually to determine if it's tracked
      for (final file in files) {
        final isTrackedResult = await Process.run('git', [
          'ls-files',
          '--error-unmatch',
          file,
        ], workingDirectory: path);

        if (isTrackedResult.exitCode == 0) {
          // File is tracked
          modifiedFiles.add(file);
        } else {
          // File is untracked
          untrackedFiles.add(file);
        }
      }

      // Discard tracked files with changes using git checkout
      if (modifiedFiles.isNotEmpty) {
        final checkoutResult = await Process.run('git', [
          'checkout',
          '--',
          ...modifiedFiles,
        ], workingDirectory: path);

        if (checkoutResult.exitCode != 0) {
          return 'Failed to discard changes: ${checkoutResult.stderr}';
        }
      }

      // Remove untracked files by deleting them from filesystem
      if (untrackedFiles.isNotEmpty) {
        for (final file in untrackedFiles) {
          final filePath = '$path/$file';
          final fileEntity = File(filePath);
          if (await fileEntity.exists()) {
            await fileEntity.delete();
          }
        }
      }

      return 'Changes discarded successfully';
    } catch (e) {
      return 'Error discarding changes: $e';
    }
  }

  // Get diff stats for a file (added/removed lines)
  /// Returns added/removed line counts for a file.
  Future<GitDiffStats> getFileDiffStats(String path, String filePath) async {
    try {
      // First check if file is tracked
      final isTrackedResult = await Process.run('git', [
        'ls-files',
        '--error-unmatch',
        filePath,
      ], workingDirectory: path);

      final isTracked = isTrackedResult.exitCode == 0;

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
      final result = await Process.run('git', [
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
      final diffResult = await Process.run('git', [
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
