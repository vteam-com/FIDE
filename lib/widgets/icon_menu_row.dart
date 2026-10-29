import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A popup menu entry's content: an icon followed by its label.
class IconMenuRow extends StatelessWidget {
  /// Creates a row showing [icon] then [label].
  const IconMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  /// Leading icon.
  final IconData icon;

  /// Icon color; the theme's when null.
  final Color? iconColor;

  /// Entry text.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.medium, color: iconColor),
        const SizedBox(width: AppSpacing.medium),
        Text(label),
      ],
    );
  }
}
