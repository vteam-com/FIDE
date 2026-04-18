part of 'git_service.dart';

/// Represents `GitDiffStats`.
class GitDiffStats {
  final int added;
  final int removed;
  final bool isNewFile;

  GitDiffStats({
    required this.added,
    required this.removed,
    required this.isNewFile,
  });

  /// Whether this diff stat contains any additions or removals.
  bool get hasChanges => added > 0 || removed > 0;
}
