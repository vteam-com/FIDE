import 'package:fide/models/shortcut_help_entry.dart';
import 'package:flutter/material.dart';

/// The right panel's tabs, in display order; each value's `index` is its
/// position in the tab bar.
enum RightPanelTab {
  outline(Key('keyTabOutline'), 'Outline', icon: Icons.list),
  localize(Key('keyTabLocalize'), 'Localize', icon: Icons.translate),
  ai(Key('keyTabAI'), 'AI', svgAsset: 'assets/ollama.svg'),
  info(Key('keyTabInfo'), 'Info', icon: Icons.info_outline);

  /// Key the integration tests find the tab by.
  final Key key;

  /// The tab's name, shown as its tooltip.
  final String label;

  /// Material icon, when the tab uses one.
  final IconData? icon;

  /// Bundled SVG drawn in the tab's icon color, when the tab uses one.
  final String? svgAsset;

  const RightPanelTab(this.key, this.label, {this.icon, this.svgAsset});

  /// The tab's tooltip: its [label].
  String get tooltip => ShortcutHelpEntry.tooltip(label);
}
