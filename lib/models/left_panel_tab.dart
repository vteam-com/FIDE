import 'package:fide/constants/constants.dart';
import 'package:fide/models/shortcut_help_entry.dart';
import 'package:flutter/material.dart';

/// The left panel's tabs, in display order; each value's `index` is its
/// position in the tab bar.
enum LeftPanelTab {
  organized(
    Key('keyTabOrganize'),
    'Organized',
    Icons.category,
    Icons.category_outlined,
    shortcut: AppShortcut.organized,
  ),
  folder(
    Key('keyTabFolder'),
    'Explorer',
    Icons.folder,
    Icons.folder_outlined,
    shortcut: AppShortcut.explorer,
  ),
  git(
    Key('keyTabGit'),
    'Git',
    Icons.commit,
    Icons.commit_outlined,
    shortcut: AppShortcut.git,
  ),
  search(
    Key('keyTabSearch'),
    'Search',
    Icons.search,
    Icons.search_outlined,
    shortcut: AppShortcut.search,
  ),
  run(Key('keyTabRun'), 'Run', Icons.play_arrow, Icons.play_arrow_outlined),
  test(
    Key('keyTabTest'),
    'Test',
    Icons.check_circle,
    Icons.check_circle_outlined,
  );

  /// Key the integration tests find the tab by.
  final Key key;

  /// The tab's name, as the View menu reads.
  final String label;

  /// Icon while the tab is showing.
  final IconData selectedIcon;

  /// Icon while another tab is showing.
  final IconData icon;

  /// Keys showing the tab, when it has any.
  final SingleActivator? shortcut;

  const LeftPanelTab(
    this.key,
    this.label,
    this.selectedIcon,
    this.icon, {
    this.shortcut,
  });

  /// The tab's tooltip: its [label] and [shortcut].
  String get tooltip => ShortcutHelpEntry.tooltip(label, shortcut);
}
