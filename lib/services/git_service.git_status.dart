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

  /// What each staged file's change is (added, modified, renamed or
  /// deleted).
  final Map<String, GitFileStatus> stagedKinds = {};

  /// What each unstaged file's change is (modified, renamed or deleted).
  final Map<String, GitFileStatus> unstagedKinds = {};

  /// Where each staged rename moved from in HEAD, by its new path.
  final Map<String, String> stagedMovedFrom = {};

  /// Where each unstaged rename moved from in the index, by its new path:
  /// a file deleted from the work tree that git pairs with an untracked
  /// one alike ([addMove]).
  final Map<String, String> unstagedMovedFrom = {};

  /// Files the move of [from], deleted from the work tree, to the
  /// untracked [to] as one unstaged rename at [to], in place of the
  /// deletion; nothing unless [from] is an unstaged deletion and [to]
  /// untracked. Call it while filling the status, before it is read.
  void addMove(String from, String to) {
    final index = unstaged.indexOf(from);
    if (index < 0 || unstagedKinds[from] != GitFileStatus.deleted) return;
    if (!untracked.remove(to)) return;
    unstaged[index] = to;
    unstagedKinds
      ..remove(from)
      ..[to] = GitFileStatus.renamed;
    unstagedMovedFrom[to] = from;
  }

  /// Where the file at [path] was in HEAD before it moved there, following
  /// an unstaged move from the index and a staged one from HEAD before it;
  /// null when it didn't move.
  String? headPathOf(String path) {
    final indexPath = unstagedMovedFrom[path] ?? path;
    final headPath = stagedMovedFrom[indexPath] ?? indexPath;
    return headPath == path ? null : headPath;
  }

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

  /// Whether the work tree may hold a move git can pair: a tracked file
  /// deleted and an untracked one to pair it with.
  bool get mayHaveMoves =>
      untracked.isNotEmpty &&
      unstagedKinds.containsValue(GitFileStatus.deleted);
}
