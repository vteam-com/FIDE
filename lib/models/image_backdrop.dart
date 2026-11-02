import 'package:flutter/material.dart';

/// What an image preview is drawn on, chosen to reveal its defects: stray
/// semi-transparent pixels, halos, or edges lost against a light or dark
/// background. Values are in display order.
enum ImageBackdrop {
  /// A checkerboard, showing which pixels are transparent.
  transparent('Transparent', Icons.grid_on),

  /// Plain black, revealing light fringes.
  black('Black', Icons.square),

  /// Plain white, revealing dark fringes.
  white('White', Icons.square_outlined),

  /// A rainbow gradient, revealing partial transparency of any color.
  rainbow('Rainbow', Icons.gradient);

  const ImageBackdrop(this.label, this.icon);

  /// Name shown in the backdrop picker.
  final String label;

  /// Glyph shown in the backdrop picker.
  final IconData icon;
}
