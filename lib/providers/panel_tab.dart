import 'package:material_ui/material_ui.dart';

/// A side panel's tab as its header shows it; the left and right panels'
/// tab enums implement it, so one widget builds both tab bars.
abstract interface class PanelTab implements Enum {
  /// Key the integration tests find the tab by.
  Key get key;

  /// Material icon, when the tab uses one.
  IconData? get icon;

  /// Bundled SVG drawn in the tab's icon color, when the tab uses one.
  String? get svgAsset;

  /// The tab's hover text.
  String get tooltip;
}
