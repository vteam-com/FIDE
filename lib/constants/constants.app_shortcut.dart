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

  /// Next Panel Tab: the left panel's tabs, then the right panel's.
  static const SingleActivator nextPanelTab = SingleActivator(
    LogicalKeyboardKey.tab,
    control: true,
  );

  /// Previous Panel Tab: [nextPanelTab] backward.
  static const SingleActivator previousPanelTab = SingleActivator(
    LogicalKeyboardKey.tab,
    control: true,
    shift: true,
  );

  /// Second keys of menu shortcuts, by the menu item's own shortcut.
  static const Map<SingleActivator, SingleActivator> aliases = {
    quickOpen: quickOpenAlias,
  };

  const AppShortcut._();
}
