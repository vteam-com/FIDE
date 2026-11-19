import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/providers/panel_tab.dart';
import 'package:material_ui/material_ui.dart';

/// The right panel's tabs, in display order; each value's `index` is its
/// position in the tab bar.
enum RightPanelTab implements PanelTab {
  info(Key('keyTabInfo'), 'Info', icon: Icons.info_outline),
  preview(Key('keyTabPreview'), 'Preview', icon: Icons.preview_outlined),
  localize(Key('keyTabLocalize'), 'Localize', icon: Icons.translate),
  analyzer(Key('keyTabAnalyzer'), 'Analyzer', icon: Icons.repeat),
  ai(Key('keyTabAI'), 'AI', svgAsset: 'assets/ollama.svg');

  @override
  final Key key;

  /// The tab's name, shown as its tooltip.
  final String label;

  @override
  final IconData? icon;

  @override
  final String? svgAsset;

  const RightPanelTab(this.key, this.label, {this.icon, this.svgAsset});

  /// The tab's tooltip: its [label].
  @override
  String get tooltip => ShortcutHelpEntry.tooltip(label);
}
