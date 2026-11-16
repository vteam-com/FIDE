import 'dart:io';

import 'package:fide/widgets/pixel_image.dart';
import 'package:material_ui/material_ui.dart';

/// A project's app icon file at [size], its pixels sharp when enlarged, or
/// [fallback] when there is none or it fails to load.
class AppIconImage extends StatelessWidget {
  /// Creates the icon for the image at [path].
  const AppIconImage({
    super.key,
    required this.path,
    required this.size,
    required this.fallback,
  });

  /// Shown when [path] is null or not a readable image.
  final Widget fallback;

  /// The icon file, or null when the project has none.
  final String? path;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconPath = path;
    if (iconPath == null) return fallback;
    // Decode at display size: app icons are often 1024px.
    final decodedSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return PixelImage(
      ResizeImage.resizeIfNeeded(
        decodedSize,
        decodedSize,
        FileImage(File(iconPath)),
      ),
      width: size,
      height: size,
      errorBuilder: (_) => fallback,
    );
  }
}
