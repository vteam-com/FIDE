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

  /// Second keys of menu shortcuts, by the menu item's own shortcut.
  static const Map<SingleActivator, SingleActivator> aliases = {
    quickOpen: quickOpenAlias,
    zoomIn: zoomInAlias,
  };

  const AppShortcut._();
}
