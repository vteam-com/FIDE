import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:flutter/material.dart';

/// A reusable status indicator widget that displays an icon with text
/// Used for showing various status states like success, error, warning, etc.
class StatusIndicator extends StatelessWidget {
  /// Creates an indicator drawing [icon], then [label] when given, in
  /// [color].
  const StatusIndicator({
    super.key,
    required this.icon,
    this.label,
    required this.color,
    this.iconSize = AppIconSize.small,
    this.textSize = AppFontSize.metadata,
    this.spacing = AppSpacing.small,
    this.fontWeight = FontWeight.w500,
    this.mainAxisSize = MainAxisSize.min,
  });

  /// The color of the icon and text
  final Color color;

  /// The font weight for the text (defaults to FontWeight.w500)
  final FontWeight fontWeight;

  /// The icon to display
  final IconData icon;

  /// The size of the icon (defaults to 14)
  final double iconSize;

  /// The text label to display next to the icon; icon only when null
  final String? label;

  /// Uses MainAxisSize.min to keep the Row compact
  final MainAxisSize mainAxisSize;

  /// The horizontal spacing between icon and text (defaults to 6)
  final double spacing;

  /// The size of the text (defaults to 11)
  final double textSize;
  @override
  Widget build(BuildContext context) {
    final text = label;
    return Row(
      mainAxisSize: mainAxisSize,
      children: [
        Icon(icon, size: iconSize, color: color),
        if (text != null) ...[
          SizedBox(width: spacing),
          Text(
            text,
            style: TextStyle(
              fontSize: textSize,
              color: color,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ],
    );
  }

  /// The success or failure mark for a finished [status], labelled unless
  /// [showLabel] is false; null while the action is idle or running.
  static StatusIndicator? forResult(
    ActionStatus status, {
    bool showLabel = true,
    double iconSize = AppIconSize.small,
  }) {
    final icon = status.resultIcon;
    final color = status.resultColor;
    if (icon == null || color == null) return null;
    return StatusIndicator(
      icon: icon,
      label: showLabel ? status.resultLabel : null,
      color: color,
      iconSize: iconSize,
    );
  }
}
