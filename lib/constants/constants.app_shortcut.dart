part of 'constants.dart';

/// Keyboard shortcuts bound in more than one place, such as a menu item
/// and an app-wide alias.
class AppShortcut {
  /// Go to File: fuzzy-find a project file by name (as in VS Code).
  static const SingleActivator quickOpen = SingleActivator(
    LogicalKeyboardKey.keyP,
    meta: true,
  );

  /// Second key for [quickOpen].
  static const SingleActivator quickOpenAlias = SingleActivator(
    LogicalKeyboardKey.keyO,
    meta: true,
  );

  /// Open File: pick any file with the platform's file dialog.
  static const SingleActivator openFile = SingleActivator(
    LogicalKeyboardKey.keyO,
    meta: true,
    shift: true,
  );

  /// Zoom In: enlarge the whole UI one level.
  static const SingleActivator zoomIn = SingleActivator(
    LogicalKeyboardKey.equal,
    meta: true,
  );

  /// Second key for [zoomIn]: ⌘+, typed with Shift on most layouts.
  static const SingleActivator zoomInAlias = SingleActivator(
    LogicalKeyboardKey.equal,
    meta: true,
    shift: true,
  );

  /// Zoom Out: shrink the whole UI one level.
  static const SingleActivator zoomOut = SingleActivator(
    LogicalKeyboardKey.minus,
    meta: true,
  );

  /// Actual Size: reset the UI zoom.
  static const SingleActivator actualSize = SingleActivator(
    LogicalKeyboardKey.digit0,
    meta: true,
  );

  /// Save: write the active document to disk.
  static const SingleActivator save = SingleActivator(
    LogicalKeyboardKey.keyS,
    meta: true,
  );

  /// Close Document: close the active editor.
  static const SingleActivator closeDocument = SingleActivator(
    LogicalKeyboardKey.keyW,
    meta: true,
  );

  /// Find: search the active document.
  static const SingleActivator find = SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: true,
  );

  /// Find Next: the active document's next match.
  static const SingleActivator findNext = SingleActivator(
    LogicalKeyboardKey.keyG,
    meta: true,
  );

  /// Find Previous: the active document's previous match.
  static const SingleActivator findPrevious = SingleActivator(
    LogicalKeyboardKey.keyG,
    meta: true,
    shift: true,
  );

  /// Go to Line: move the caret to a line of the active document.
  static const SingleActivator goToLine = SingleActivator(
    LogicalKeyboardKey.keyG,
    control: true,
  );

  /// Refresh Status: reload the open project's Git state.
  static const SingleActivator refreshGitStatus = SingleActivator(
    LogicalKeyboardKey.keyR,
    meta: true,
    shift: true,
  );

  /// Quit: close the app.
  static const SingleActivator quit = SingleActivator(
    LogicalKeyboardKey.keyQ,
    meta: true,
  );

  /// Settings: show the settings screen.
  static const SingleActivator settings = SingleActivator(
    LogicalKeyboardKey.comma,
    meta: true,
  );

  /// Left panel: cycle it through Hide, Min and Max.
  static const SingleActivator panelLeft = SingleActivator(
    LogicalKeyboardKey.digit1,
    meta: true,
  );

  /// Bottom panel: cycle it through Hide, Min and Max.
  static const SingleActivator panelBottom = SingleActivator(
    LogicalKeyboardKey.digit2,
    meta: true,
  );

  /// Right panel: cycle it through Hide, Min and Max.
  static const SingleActivator panelRight = SingleActivator(
    LogicalKeyboardKey.digit3,
    meta: true,
  );

  /// Show the left panel's next tab.
  static const SingleActivator nextLeftPanelTab = SingleActivator(
    LogicalKeyboardKey.digit1,
    control: true,
  );

  /// Show the right panel's next tab.
  static const SingleActivator nextRightPanelTab = SingleActivator(
    LogicalKeyboardKey.digit3,
    control: true,
  );

  /// Show the left panel's Organized tab.
  static const SingleActivator organized = SingleActivator(
    LogicalKeyboardKey.keyJ,
    meta: true,
    shift: true,
  );

  /// Show the left panel's Explorer tab.
  static const SingleActivator explorer = SingleActivator(
    LogicalKeyboardKey.keyE,
    meta: true,
    shift: true,
  );

  /// Show the left panel's Git tab.
  static const SingleActivator git = SingleActivator(
    LogicalKeyboardKey.keyG,
    control: true,
    shift: true,
  );

  /// Show the left panel's Search tab.
  static const SingleActivator search = SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: true,
    shift: true,
  );

  /// Second keys of menu shortcuts, by the menu item's own shortcut.
  static const Map<SingleActivator, SingleActivator> aliases = {
    quickOpen: quickOpenAlias,
    zoomIn: zoomInAlias,
  };

  const AppShortcut._();
}
