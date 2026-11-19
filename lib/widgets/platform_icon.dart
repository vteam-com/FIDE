import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/widgets/svg_icon.dart';
import 'package:material_ui/material_ui.dart';

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
    return IconTheme.merge(
      data: IconThemeData(
        size: size,
        color: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(
                alpha: isSupported ? AppOpacity.emphasis : AppOpacity.faint,
              ),
      ),
      child: SvgIcon(platform.iconAsset),
    );
  }
}
