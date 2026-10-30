import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A muted [message], optionally under a large [icon], centered in a panel
/// that has nothing to show yet.
class EmptyState extends StatelessWidget {
  /// Creates the placeholder for [message].
  const EmptyState({super.key, required this.message, this.icon});

  /// Large glyph shown above [message]; none when null.
  final IconData? icon;

  /// Why the panel is empty, or what to do to fill it.
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xLarge,
        children: [
          if (icon != null)
            Icon(icon, size: AppIconSize.emptyState, color: color),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppFontSize.label, color: color),
          ),
        ],
      ),
    );
  }
}
