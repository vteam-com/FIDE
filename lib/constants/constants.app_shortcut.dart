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

  const AppShortcut._();
}
