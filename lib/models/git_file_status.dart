/// A file's state in Git, as `git status --porcelain` reports it.
enum GitFileStatus {
  untracked, // ? - New file, not tracked by Git
  added, // A - Added to staging area
  modified, // M - Modified
  deleted, // D - Deleted
  renamed, // R - Renamed
  copied, // C - Copied
  updated, // U - Updated but unmerged
  ignored, // ! - Ignored
  clean, // No changes
}

/// Shared display helpers for Git status values.
extension GitFileStatusDisplay on GitFileStatus {
  /// Returns the badge symbol for this Git status.
  String badgeSymbol({String deletedSymbol = '-'}) {
    switch (this) {
      case GitFileStatus.modified:
        return '●';
      case GitFileStatus.added:
        return '+';
      case GitFileStatus.deleted:
        return deletedSymbol;
      case GitFileStatus.untracked:
        return '?';
      case GitFileStatus.ignored:
        return '!';
      default:
        return '';
    }
  }
}
