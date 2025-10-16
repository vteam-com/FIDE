import 'package:flutter/material.dart';

/// A reusable status indicator widget that displays an icon with text
/// Used for showing various status states like success, error, warning, etc.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 14,
    this.textSize = 11,
    this.spacing = 6,
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

  /// The text label to display next to the icon
  final String label;

  /// Uses MainAxisSize.min to keep the Row compact
  final MainAxisSize mainAxisSize;

  /// The horizontal spacing between icon and text (defaults to 6)
  final double spacing;

  /// The size of the text (defaults to 11)
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      children: [
        Icon(icon, size: iconSize, color: color),
        SizedBox(width: spacing),
        Text(
          label,
          style: TextStyle(
            fontSize: textSize,
            color: color,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}
