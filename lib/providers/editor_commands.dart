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

  /// Moves the caret to [lineNumber] (1-based) and [column], and focuses it.
  void navigateToLine(int lineNumber, {int column = 1});

  /// Saves the active document to disk.
  void save();

  /// Shows or hides the in-editor search bar.
  void toggleSearch();
}
