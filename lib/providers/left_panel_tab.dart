import 'package:fide/constants/constants.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/providers/panel_tab.dart';
import 'package:material_ui/material_ui.dart';

/// The left panel's tabs, in display order; each value's `index` is its
/// position in the tab bar.
enum LeftPanelTab implements PanelTab {
  folder(
    Key('keyTabFolder'),
    'Explorer',
    Icons.folder_outlined,
    shortcut: AppShortcut.explorer,
  ),
  organized(
    Key('keyTabOrganize'),
    'Organized',
    Icons.category_outlined,
    shortcut: AppShortcut.organized,
  ),
  git(
    Key('keyTabGit'),
    'Git',
    Icons.commit_outlined,
    shortcut: AppShortcut.git,
  ),
  search(
    Key('keyTabSearch'),
    'Search',
    Icons.search_outlined,
    shortcut: AppShortcut.search,
  ),
  run(Key('keyTabRun'), 'Run', Icons.play_arrow_outlined),
  test(Key('keyTabTest'), 'Test', Icons.check_circle_outlined);

  @override
  final Key key;

  /// The tab's name, as the View menu reads.
  final String label;

  @override
  final IconData icon;

  /// Keys showing the tab, when it has any.
  final SingleActivator? shortcut;

  const LeftPanelTab(this.key, this.label, this.icon, {this.shortcut});

  @override
  String? get svgAsset => null;

  /// The tab's tooltip: its [label] and [shortcut].
  @override
  String get tooltip => ShortcutHelpEntry.tooltip(label, shortcut);
}
