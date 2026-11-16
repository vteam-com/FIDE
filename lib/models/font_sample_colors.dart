import 'package:fide/models/image_backdrop.dart';
import 'package:material_ui/material_ui.dart';

/// The ink and paper the font viewer draws its samples in; values are in
/// display order.
enum FontSampleColors {
  /// Black text on a white page.
  blackOnWhite('Black on white', Colors.black, ImageBackdrop.white),

  /// White text on a black page.
  whiteOnBlack('White on black', Colors.white, ImageBackdrop.black);

  const FontSampleColors(this.label, this.foreground, this.paper);

  /// Name shown as the choice's tooltip.
  final String label;

  /// Color of the text.
  final Color foreground;

  /// What the text is drawn on, one of the image viewer's plain
  /// backdrops, whose glyph also marks the choice.
  final ImageBackdrop paper;
}
