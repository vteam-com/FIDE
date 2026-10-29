import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A small, unpadded icon button for toolbars and panel headers.
class CompactIconButton extends StatelessWidget {
  /// Creates a button showing [icon] that calls [onPressed].
  const CompactIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  /// Icon color; the theme's when null.
  final Color? color;

  /// The glyph shown.
  final IconData icon;

  /// Called on tap; the button is disabled when null.
  final VoidCallback? onPressed;

  /// Hover text naming the action.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.medium, color: color),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: AppSize.compactIconButton,
        minHeight: AppSize.compactIconButton,
      ),
    );
  }
}
