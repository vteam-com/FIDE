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

  // Hash lookups for [statusOf], built on first use so tagging every node of
  // a large tree stays linear instead of scanning the lists per file
  late final Set<String> _stagedSet = staged.toSet();
  late final Set<String> _unstagedSet = unstaged.toSet();
  late final Set<String> _untrackedSet = untracked.toSet();

  /// What each staged file's change is (added, modified or deleted).
  final Map<String, GitFileStatus> stagedKinds = {};

  /// What each unstaged file's change is (modified or deleted).
  final Map<String, GitFileStatus> unstagedKinds = {};

  /// Status of the file at [relativePath] (relative to the repository root);
  /// staged changes take precedence over unstaged ones.
  GitFileStatus statusOf(String relativePath) {
    if (_stagedSet.contains(relativePath)) {
      return stagedKinds[relativePath] ?? GitFileStatus.added;
    }
    if (_unstagedSet.contains(relativePath)) {
      return unstagedKinds[relativePath] ?? GitFileStatus.modified;
    }
    if (_untrackedSet.contains(relativePath)) return GitFileStatus.untracked;
    return GitFileStatus.clean;
  }

  /// Number of distinct files with staged, unstaged or untracked changes.
  int get changedFileCount =>
      {..._stagedSet, ..._unstagedSet, ..._untrackedSet}.length;

  /// Whether any tracked or untracked changes are present.
  bool get hasChanges =>
      staged.isNotEmpty || unstaged.isNotEmpty || untracked.isNotEmpty;
}
