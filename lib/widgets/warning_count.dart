import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:flutter/material.dart';

/// A small orange [icon] and [count] flagging a rule breach, explained by
/// [message] on hover.
class WarningCount extends StatelessWidget {
  /// Creates a warning showing [count] next to [icon].
  const WarningCount({
    super.key,
    required this.icon,
    required this.count,
    required this.message,
  });

  /// The number shown after [icon].
  final int count;

  /// The glyph naming what is counted.
  final IconData icon;

  /// The tooltip explaining the warning.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.small, color: AppTheme.warningColor),
          const SizedBox(width: AppSpacing.micro),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: AppFontSize.metadata,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }
}
