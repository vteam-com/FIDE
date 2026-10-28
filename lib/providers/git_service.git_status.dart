part of 'git_service.dart';

/// Represents `GitStatus`.
class GitStatus {
  final List<String> staged;
  final List<String> unstaged;
  final List<String> untracked;

  GitStatus({
    required this.staged,
    required this.unstaged,
    required this.untracked,
  });

  /// Status of the file at [relativePath] (relative to the repository root);
  /// staged changes take precedence over unstaged ones.
  GitFileStatus statusOf(String relativePath) {
    if (staged.contains(relativePath)) return GitFileStatus.added;
    if (unstaged.contains(relativePath)) return GitFileStatus.modified;
    if (untracked.contains(relativePath)) return GitFileStatus.untracked;
    return GitFileStatus.clean;
  }

  /// Whether any tracked or untracked changes are present.
  bool get hasChanges =>
      staged.isNotEmpty || unstaged.isNotEmpty || untracked.isNotEmpty;
}
