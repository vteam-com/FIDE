import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:material_ui/material_ui.dart';

/// The two ways to apply the saved code to a running app, as the Run
/// panel's buttons and the Run menu offer them.
enum HotReload {
  /// Hot reload: the app runs the saved code and keeps its state.
  reload(
    'Hot Reload',
    Icons.bolt,
    AppShortcut.hotReload,
    ActionStatus.reloading,
  ),

  /// Hot restart: the app starts over on the saved code, its state reset.
  restart(
    'Hot Restart',
    Icons.restart_alt,
    AppShortcut.hotRestart,
    ActionStatus.restarting,
  );

  const HotReload(this.label, this.icon, this.shortcut, this.status);

  /// Glyph of its button.
  final IconData icon;

  /// Its name, as its menu item reads.
  final String label;

  /// Keys running it.
  final SingleActivator shortcut;

  /// The status of the app's action while it applies.
  final ActionStatus status;

  /// Hover text of its button: its [label] and [shortcut].
  String get tooltip => ShortcutHelpEntry.tooltip(label, shortcut);
}
