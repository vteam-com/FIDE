part of 'constants.dart';

/// One-off named colours that do not belong to the Material colour scheme.
class AppColor {
  static const Color popupBorderLight = Color(0xFFCCCCCC);
  static const Color popupBorderDark = Color(0xFF4A4A4A);

  /// The two squares of the checkerboard showing an image's transparency.
  static const Color transparencyLight = Color(0xFFFFFFFF);
  static const Color transparencyDark = Color(0xFFD6D6D6);

  /// The ground of the blend backdrop behind an image preview, showing
  /// between its [blendSpots].
  static const Color blendBase = Color(0xFF4F7CAC);

  /// The soft spots of color melting into one another over [blendBase]
  /// behind an image preview: unrelated hues scattered out of spectrum
  /// order, so each region mixes different light, dark and saturated tones;
  /// placed in a near-square cell, repeated along a long box.
  static const List<({Alignment center, Color color})> blendSpots = [
    (center: Alignment(-0.85, -0.75), color: Color(0xFFFF6F61)),
    (center: Alignment(0.15, -0.95), color: Color(0xFFFFD166)),
    (center: Alignment(0.85, -0.55), color: Color(0xFF8E44EC)),
    (center: Alignment(-0.35, -0.05), color: Color(0xFF7BE0AD)),
    (center: Alignment(0.45, 0.2), color: Color(0xFFFF5DA2)),
    (center: Alignment(-0.95, 0.55), color: Color(0xFF2B2D7C)),
    (center: Alignment(0.0, 0.85), color: Color(0xFFFF9F1C)),
    (center: Alignment(0.9, 0.9), color: Color(0xFF14B8A6)),
  ];

  /// Marks the pixels that differ in an image diff's Difference mode.
  static const Color imageDiffChanged = Color(0xFFFF00FF);

  const AppColor._();
}
