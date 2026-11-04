import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:flutter/material.dart';

/// Up and down arrows stepping through a list of places, such as find
/// matches or a diff's changes, followed by a caption such as "2 of 5".
class PreviousNextButtons extends StatelessWidget {
  /// Creates the arrows calling [onPrevious] and [onNext], then [label].
  const PreviousNextButtons({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
  });

  /// The caption after the arrows, such as the position or the count.
  final String label;

  /// The down arrow's tooltip.
  final String nextTooltip;

  /// Goes to the next place; the down arrow is disabled when null.
  final VoidCallback? onNext;

  /// Goes to the previous place; the up arrow is disabled when null.
  final VoidCallback? onPrevious;

  /// The up arrow's tooltip.
  final String previousTooltip;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactIconButton(
          icon: Icons.keyboard_arrow_up,
          tooltip: previousTooltip,
          onPressed: onPrevious,
        ),
        CompactIconButton(
          icon: Icons.keyboard_arrow_down,
          tooltip: nextTooltip,
          onPressed: onNext,
        ),
        const SizedBox(width: AppSpacing.medium),
        Text(label, style: AppTextStyle.caption),
      ],
    );
  }
}
