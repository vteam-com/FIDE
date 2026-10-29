import 'package:flutter/material.dart';

/// The left panel's tabs, in display order; each value's `index` is its
/// position in the tab bar.
enum LeftPanelTab {
  organized(Key('keyTabOrganize'), Icons.category, Icons.category_outlined),
  folder(Key('keyTabFolder'), Icons.folder, Icons.folder_outlined),
  git(Key('keyTabGit'), Icons.commit, Icons.commit_outlined),
  search(Key('keyTabSearch'), Icons.search, Icons.search_outlined),
  run(Key('keyTabRun'), Icons.play_arrow, Icons.play_arrow_outlined),
  test(Key('keyTabTest'), Icons.check_circle, Icons.check_circle_outlined);

  /// Key the integration tests find the tab by.
  final Key key;

  /// Icon while the tab is showing.
  final IconData selectedIcon;

  /// Icon while another tab is showing.
  final IconData icon;

  const LeftPanelTab(this.key, this.selectedIcon, this.icon);
}
