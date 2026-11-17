import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/count_badge.dart';
import 'package:fide/widgets/task_ring.dart';
import 'package:material_ui/material_ui.dart';

/// A side panel's tab header: [icon] with a [CountBadge] of [badgeCount],
/// a [TaskRing] spinning around it while [busy], and [tooltip] on hover.
/// Shared by the left and right panels so their tabs read alike.
class PanelTabHeader extends StatelessWidget {
  /// Creates the header of a tab showing [icon].
  const PanelTabHeader({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.badgeCount,
    required this.busy,
  });

  /// Pending items flagged on the icon; no badge while zero.
  final int badgeCount;

  /// Whether the tab's panel has work running, ringing the icon.
  final bool busy;

  /// The tab's glyph.
  final Widget icon;

  /// The tab's name and shortcut, shown on hover.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Tab(
        icon: TaskRing(
          size: AppSize.panelTabRing,
          spinning: busy,
          child: IconTheme.merge(
            data: const IconThemeData(size: AppIconSize.panelHeader),
            child: CountBadge(count: badgeCount, child: icon),
          ),
        ),
      ),
    );
  }
}
