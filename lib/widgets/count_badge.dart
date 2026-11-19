import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:material_ui/material_ui.dart';

/// An orange counter overlaid on the corner of [child], such as a tab icon,
/// flagging pending items; hidden while [count] is zero. It is a
/// [BadgeStatus], so it looks like every other badge of the app.
class CountBadge extends StatelessWidget {
  /// Creates a badge showing [count] over [child].
  const CountBadge({super.key, required this.count, required this.child});

  /// The widget the badge decorates.
  final Widget child;

  /// The number shown; no badge while zero.
  final int count;

  @override
  Widget build(BuildContext context) {
    // Always a stack, so [child] keeps its state as the count comes and goes
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          PositionedDirectional(
            top: -AppSpacing.tiny,
            end: -AppSpacing.small,
            child: BadgeStatus.warning(text: '$count'),
          ),
      ],
    );
  }
}
