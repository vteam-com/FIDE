import 'dart:io';
import '../utils/file_utils.dart';

class GitService {
  static final GitService _instance = GitService._internal();
  factory GitService() => _instance;
  GitService._internal();

  // Check if Git is available
  Future<bool> isGitAvailable() async {
    try {
      final result = await Process.run('git', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  // Check if directory is a Git repository
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
          if (line.length < 3) continue;
          final status = line.substring(0, 2);
          final file = line.substring(3);

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
  Future<String> stageFiles(String path, List<String> files) async {
    try {
      final args = ['add', ...files];
      final result = await Process.run('git', args, workingDirectory: path);
      if (result.exitCode == 0) {
        return 'Files staged successfully';
      } else {
        return 'Failed to stage files: ${result.stderr}';
      }
    } catch (e) {
      return 'Error staging files: $e';
    }
  }

  // Unstage files
  Future<String> unstageFiles(String path, List<String> files) async {
    try {
      final args = ['reset', 'HEAD', ...files];
      final result = await Process.run('git', args, workingDirectory: path);
      if (result.exitCode == 0) {
        return 'Files unstaged successfully';
      } else {
        return 'Failed to unstage files: ${result.stderr}';
      }
    } catch (e) {
      return 'Error unstaging files: $e';
    }
  }

  // Commit changes
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
  Future<List<GitCommit>> getRecentCommits(
    String path, {
    int count = 10,
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
        final content = await FileUtils.readFileContentSafely(file);
        if (content == FileUtils.fileTooBigMessage) {
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
  Future<String> getStagedDiff(String path, String filePath) async {
    try {
      final result = await Process.run('git', [
        'diff',
        '--cached',
        '--',
        filePath,
      ], workingDirectory: path);
      return result.exitCode == 0 ? result.stdout.toString() : '';
    } catch (e) {
      return 'Error getting staged diff: $e';
    }
  }

  // Get diff for unstaged files
  Future<String> getUnstagedDiff(String path, String filePath) async {
    try {
      final result = await Process.run('git', [
        'diff',
        '--',
        filePath,
      ], workingDirectory: path);
      return result.exitCode == 0 ? result.stdout.toString() : '';
    } catch (e) {
      return 'Error getting unstaged diff: $e';
    }
  }

  // Get file content at a specific revision
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

  // Get diff stats for a file (added/removed lines)
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
          final content = await FileUtils.readFileContentSafely(file);
          if (content == FileUtils.fileTooBigMessage) {
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
        if (parts.length >= 2) {
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

class GitStatus {
  final List<String> staged;
  final List<String> unstaged;
  final List<String> untracked;

  GitStatus({
    required this.staged,
    required this.unstaged,
    required this.untracked,
  });

  bool get hasChanges =>
      staged.isNotEmpty || unstaged.isNotEmpty || untracked.isNotEmpty;
}

class GitCommit {
  final String hash;
  final String message;

  GitCommit({required this.hash, required this.message});
}

class GitDiffStats {
  final int added;
  final int removed;
  final bool isNewFile;

  GitDiffStats({
    required this.added,
    required this.removed,
    required this.isNewFile,
  });

  String get displayString {
    if (added == 0 && removed == 0) return '';
    final parts = <String>[];
    if (added > 0) parts.add('+$added');
    if (removed > 0) parts.add('-$removed');
    return parts.join(' ');
  }

  bool get hasChanges => added > 0 || removed > 0;
}
