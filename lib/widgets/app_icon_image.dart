import 'dart:io';

import 'package:flutter/material.dart';

/// A project's app icon file at [size], or [fallback] when there is none or
/// it fails to load.
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
    return Image.file(
      File(iconPath),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
