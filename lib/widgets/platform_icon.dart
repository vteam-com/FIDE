// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The bundled SVG icon of [platform], tinted by state: primary when
/// [isSelected], muted when [isSupported], faint otherwise.
class PlatformIcon extends StatelessWidget {
  /// Creates the icon of [platform].
  const PlatformIcon({
    super.key,
    required this.platform,
    required this.size,
    required this.isSupported,
    this.isSelected = false,
  });

  /// Whether to draw the icon in the primary color.
  final bool isSelected;

  /// Whether the project has a folder for [platform].
  final bool isSupported;

  /// The platform drawn.
  final FlutterPlatform platform;

  /// Width and height of the icon.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(
                alpha: isSupported ? AppOpacity.emphasis : AppOpacity.faint,
              ),
        BlendMode.srcIn,
      ),
      child: SvgPicture.asset(platform.iconAsset, width: size, height: size),
    );
  }
}
