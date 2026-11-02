import 'package:flutter/material.dart';

/// [child] with a pointer cursor that calls [onTap] when clicked and
/// [onDoubleTap] when double-clicked; just [child] when both are null.
class Clickable extends StatelessWidget {
  /// Makes [child] clickable through [onTap].
  const Clickable({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
  });

  /// The widget to click.
  final Widget child;

  /// Called on double-click.
  final VoidCallback? onDoubleTap;

  /// Called on click.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onDoubleTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: child,
      ),
    );
  }
}
