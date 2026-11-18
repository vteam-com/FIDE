/// What an image preview is drawn on, chosen to reveal its defects: stray
/// semi-transparent pixels, halos, or edges lost against a light or dark
/// background. Values are in display order.
enum ImageBackdrop {
  /// A checkerboard, showing which pixels are transparent.
  transparent('Transparent'),

  /// Plain black, revealing light fringes.
  black('Black'),

  /// Plain white, revealing dark fringes.
  white('White'),

  /// Soft spots of unrelated hues blended together, revealing partial
  /// transparency of any color.
  blend('Blend');

  const ImageBackdrop(this.label);

  /// Name shown in the backdrop picker.
  final String label;
}
