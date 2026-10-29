import 'package:flutter/material.dart';

/// The right panel's tabs, in display order; each value's `index` is its
/// position in the tab bar.
enum RightPanelTab {
  outline(Key('keyTabOutline'), icon: Icons.list),
  localize(Key('keyTabLocalize'), icon: Icons.translate),
  ai(Key('keyTabAI'), svgAsset: 'assets/ollama.svg'),
  info(Key('keyTabInfo'), icon: Icons.info_outline);

  /// Key the integration tests find the tab by.
  final Key key;

  /// Material icon, when the tab uses one.
  final IconData? icon;

  /// Bundled SVG drawn in the tab's icon color, when the tab uses one.
  final String? svgAsset;

  const RightPanelTab(this.key, {this.icon, this.svgAsset});
}
