import 'package:fide/constants/constants.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Whether each [SidePanel] is shown; the left and right ones are at
/// start.
final sidePanelVisibleProvider = StateProvider.family<bool, SidePanel>(
  (_, panel) => panel.shownAtStart,
);

/// Whether each [SidePanel] is expanded to its largest size; restoring it
/// brings back the size it had.
final sidePanelExpandedProvider = StateProvider.family<bool, SidePanel>(
  (_, _) => false,
);

/// The panels around the editor, in the title bar's order; each one
/// cycles through Hide, Min and Max from its title-bar button, its View
/// menu item and its [shortcut].
enum SidePanel {
  left('Left', 'assets/toggle_panel_left.svg', AppShortcut.panelLeft),
  bottom(
    'Bottom',
    'assets/toggle_panel_bottom.svg',
    AppShortcut.panelBottom,
    shownAtStart: false,
  ),
  right('Right', 'assets/toggle_panel_right.svg', AppShortcut.panelRight);

  /// Where the panel sits, such as `Left`.
  final String label;

  /// The title-bar button's icon.
  final String asset;

  /// Keys cycling the panel's size.
  final SingleActivator shortcut;

  /// Whether the panel is shown when the app starts.
  final bool shownAtStart;

  const SidePanel(
    this.label,
    this.asset,
    this.shortcut, {
    this.shownAtStart = true,
  });

  /// The command cycling the panel's size, as its View menu item reads.
  String get commandLabel => '$label Panel: Hide, Min, Max';

  /// Whether the panel is expanded to its largest size; restoring it
  /// brings back the size it had.
  StateProvider<bool> get expandedProvider => sidePanelExpandedProvider(this);

  /// Key the integration tests find the title-bar button by.
  Key get toggleKey => Key('togglePanel$label');

  /// The title-bar button's tooltip: its [commandLabel] and [shortcut].
  String get tooltip => ShortcutHelpEntry.tooltip(commandLabel, shortcut);

  /// Whether the panel is shown.
  StateProvider<bool> get visibleProvider => sidePanelVisibleProvider(this);
}
