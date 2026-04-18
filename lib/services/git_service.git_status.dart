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

  /// Whether any tracked or untracked changes are present.
  bool get hasChanges =>
      staged.isNotEmpty || unstaged.isNotEmpty || untracked.isNotEmpty;
}
