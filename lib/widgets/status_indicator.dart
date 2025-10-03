import 'package:flutter/material.dart';

/// A reusable status indicator widget that displays an icon with text
/// Used for showing various status states like success, error, warning, etc.
class StatusIndicator extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// The text label to display next to the icon
  final String label;

  /// The color of the icon and text
  final Color color;

  /// The size of the icon (defaults to 14)
  final double iconSize;

  /// The size of the text (defaults to 11)
  final double textSize;

  /// The horizontal spacing between icon and text (defaults to 6)
  final double spacing;

  /// The font weight for the text (defaults to FontWeight.w500)
  final FontWeight fontWeight;

  /// Uses MainAxisSize.min to keep the Row compact
  final MainAxisSize mainAxisSize;

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
