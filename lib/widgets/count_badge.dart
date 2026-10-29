import 'package:fide/models/app_theme.dart';
import 'package:flutter/material.dart';

/// An orange counter overlaid on the corner of [child], such as a tab icon,
/// flagging pending items; hidden while [count] is zero.
class CountBadge extends StatelessWidget {
  /// Creates a badge showing [count] over [child].
  const CountBadge({super.key, required this.count, required this.child});

  /// The widget the badge decorates.
  final Widget child;

  /// The number shown; the badge is hidden when it is zero.
  final int count;
  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: count,
      isLabelVisible: count > 0,
      backgroundColor: AppTheme.warningColor,
      textColor: AppTheme.warningText,
      child: child,
    );
  }
}
