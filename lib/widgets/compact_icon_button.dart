import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/svg_icon.dart';
import 'package:flutter/material.dart';

/// A small, unpadded icon button for toolbars and panel headers; a
/// [selected] one, such as a toggle that is on, shows in the primary color.
class CompactIconButton extends StatelessWidget {
  /// Creates a button showing [icon] that calls [onPressed].
  const CompactIconButton({
    super.key,
    required IconData this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.selected = false,
  }) : svgAsset = null,
       iconSize = AppIconSize.medium,
       size = AppSize.compactIconButton;

  /// Creates a button for the strip atop a panel, its icon as large as
  /// the side panels' tab icons and as tall as the strip.
  const CompactIconButton.header({
    super.key,
    required IconData this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.selected = false,
  }) : svgAsset = null,
       iconSize = AppIconSize.panelHeader,
       size = AppSize.panelHeaderHeight;

  /// Creates a button showing the SVG icon [svgAsset].
  const CompactIconButton.svg({
    super.key,
    required String this.svgAsset,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  }) : icon = null,
       color = null,
       iconSize = AppIconSize.medium,
       size = AppSize.compactIconButton;

  /// Icon color; the theme's when null.
  final Color? color;

  /// The glyph shown, unless [svgAsset] is.
  final IconData? icon;

  /// The glyph's size.
  final double iconSize;

  /// Called on tap; the button is disabled when null.
  final VoidCallback? onPressed;

  /// Whether the button shows as on, in the primary color.
  final bool selected;

  /// The button's least width and height.
  final double size;

  /// The SVG glyph shown in place of [icon].
  final String? svgAsset;

  /// Hover text naming the action.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final svgAsset = this.svgAsset;
    return IconButton(
      onPressed: onPressed,
      icon: svgAsset == null ? Icon(icon) : SvgIcon(svgAsset),
      iconSize: iconSize,
      color: selected ? Theme.of(context).colorScheme.primary : color,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size, minHeight: size),
    );
  }
}
