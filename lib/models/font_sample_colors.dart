import 'package:material_ui/material_ui.dart';

/// The ink and paper the font viewer draws its samples in; values are in
/// display order.
enum FontSampleColors {
  /// Black text on a white page.
  blackOnWhite(
    'Black on white',
    Icons.square_outlined,
    Colors.black,
    Colors.white,
  ),

  /// White text on a black page.
  whiteOnBlack('White on black', Icons.square, Colors.white, Colors.black);

  const FontSampleColors(
    this.label,
    this.icon,
    this.foreground,
    this.background,
  );

  /// Name shown as the choice's tooltip.
  final String label;

  /// Glyph of the choice, the same as the image viewer's plain backdrops.
  final IconData icon;

  /// Color of the text.
  final Color foreground;

  /// Color behind the text.
  final Color background;
}
