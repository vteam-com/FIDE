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
  }) : iconSize = AppIconSize.medium,
       size = AppSize.compactIconButton;

  /// Creates a button for the strip atop a panel, its icon as large as
  /// the side panels' tab icons and as tall as the strip.
  const CompactIconButton.header({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  }) : iconSize = AppIconSize.panelHeader,
       size = AppSize.panelHeaderHeight;

  /// Icon color; the theme's when null.
  final Color? color;

  /// The glyph shown.
  final IconData icon;

  /// The glyph's size.
  final double iconSize;

  /// Called on tap; the button is disabled when null.
  final VoidCallback? onPressed;

  /// The button's least width and height.
  final double size;

  /// Hover text naming the action.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize, color: color),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size, minHeight: size),
    );
  }
}
