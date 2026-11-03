/// What loading an editor's git diff found.
enum EditorDiffOutcome {
  /// The committed and current texts differ and are loaded.
  loaded,

  /// The file is not in a Git repository.
  notGitRepository,

  /// The committed text is the current text.
  unchanged,
}
