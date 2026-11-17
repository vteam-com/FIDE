import 'dart:math' as math;

import 'package:fide/constants/constants.dart';

/// What the layout knows of a side panel: whether it is [shown], whether
/// it is [expanded] to share the room left by the other, and the [width]
/// the user dragged it to.
typedef SidePanelSize = ({bool shown, bool expanded, double width});

/// Fits the side panels around the editor so it always keeps
/// [AppSize.editorMinWidth].
class SidePanelWidths {
  const SidePanelWidths._();

  /// The widths [left] and [right] take in [availableWidth]: an expanded
  /// panel shares what the others leave, up to
  /// [AppSize.maxSidePanelWidth]; a dragged one keeps its width. When
  /// they leave the editor less than [AppSize.editorMinWidth], the shown
  /// panels shrink in proportion to how far each is above
  /// [AppSize.minSidePanelWidth], never below it. A hidden panel keeps
  /// its width.
  static ({double left, double right}) fit(
    double availableWidth, {
    required SidePanelSize left,
    required SidePanelSize right,
  }) {
    final shown = [left, right].where((panel) => panel.shown);
    final room =
        availableWidth -
        AppSize.editorMinWidth -
        shown.length * AppSize.splitterThickness;
    final fixedWidth = shown
        .where((panel) => !panel.expanded)
        .fold(0.0, (sum, panel) => sum + panel.width);
    final expandedCount = shown.where((panel) => panel.expanded).length;
    final expandedWidth = expandedCount == 0
        ? 0.0
        : ((room - fixedWidth) / expandedCount).clamp(
            AppSize.minSidePanelWidth,
            AppSize.maxSidePanelWidth,
          );

    double wanted(SidePanelSize panel) =>
        panel.shown && panel.expanded ? expandedWidth : panel.width;
    double slack(SidePanelSize panel) => panel.shown
        ? math.max(0, wanted(panel) - AppSize.minSidePanelWidth)
        : 0;

    final totalSlack = slack(left) + slack(right);
    final overflow =
        shown.fold(0.0, (sum, panel) => sum + wanted(panel)) - room;
    if (overflow <= 0 || totalSlack == 0) {
      return (left: wanted(left), right: wanted(right));
    }
    final cut = math.min(overflow, totalSlack);
    double fitted(SidePanelSize panel) =>
        wanted(panel) - cut * slack(panel) / totalSlack;
    return (left: fitted(left), right: fitted(right));
  }
}
