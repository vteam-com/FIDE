/// Commands the app shell (menus, shortcuts, panels) sends to the editor.
///
/// Implemented by the mounted editor and by `ActiveEditor`, which routes
/// each call to whichever editor is currently attached.
abstract interface class EditorCommands {
  /// Closes the active document.
  void close();

  /// Selects the next search match.
  void findNext();

  /// Selects the previous search match.
  void findPrevious();

  /// Opens the in-editor search bar and focuses it, starting from the
  /// selected text when there is a [searchSeed].
  void openSearch();

  /// Moves the caret to [lineNumber] (1-based) and [column], and focuses it.
  void navigateToLine(int lineNumber, {int column = 1});

  /// Saves the active document to disk.
  void save();

  /// The selected text a search should start with, or empty when nothing
  /// usable is selected.
  String get searchSeed;
}
