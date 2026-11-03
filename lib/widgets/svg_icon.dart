import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The SVG [asset] drawn as an icon: sized and tinted by the ambient
/// [IconTheme], as an [Icon] is, so it fits wherever an icon goes.
class SvgIcon extends StatelessWidget {
  /// Creates the icon drawing [asset].
  const SvgIcon(this.asset, {super.key});

  /// The SVG asset path.
  final String asset;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size;
    final color = theme.color;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
