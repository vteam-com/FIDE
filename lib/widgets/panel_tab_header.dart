import 'package:fide/widgets/count_badge.dart';
import 'package:flutter/material.dart';

/// A side panel's tab header: [icon] with a [CountBadge] of [badgeCount],
/// and [tooltip] on hover. Shared by the left and right panels so their
/// tabs read alike.
class PanelTabHeader extends StatelessWidget {
  /// Creates the header of a tab showing [icon].
  const PanelTabHeader({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.badgeCount,
  });

  /// Pending items flagged on the icon; no badge while zero.
  final int badgeCount;

  /// The tab's glyph.
  final Widget icon;

  /// The tab's name and shortcut, shown on hover.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Tab(
        icon: CountBadge(count: badgeCount, child: icon),
      ),
    );
  }
}
