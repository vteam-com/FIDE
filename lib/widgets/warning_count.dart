import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/status_indicator.dart';
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
    this.onTap,
  });

  /// The number shown after [icon].
  final int count;

  /// The glyph naming what is counted.
  final IconData icon;

  /// The tooltip explaining the warning.
  final String message;

  /// Called when the warning is clicked, to fix it; null when it can't be.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Tooltip(
        message: message,
        child: StatusIndicator(
          icon: icon,
          label: '$count',
          color: StatusTone.warning.color,
        ),
      ),
    );
  }
}
