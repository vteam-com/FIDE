import 'package:flutter/material.dart';

/// [child] with a pointer cursor that calls [onTap] when clicked; just
/// [child] when [onTap] is null.
class Clickable extends StatelessWidget {
  /// Makes [child] clickable through [onTap].
  const Clickable({super.key, required this.child, this.onTap});

  /// The widget to click.
  final Widget child;

  /// Called on click; null leaves [child] as is.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}
