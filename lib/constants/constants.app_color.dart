part of 'constants.dart';

/// One-off named colours that do not belong to the Material colour scheme.
class AppColor {
  static const Color popupBorderLight = Color(0xFFCCCCCC);
  static const Color popupBorderDark = Color(0xFF4A4A4A);

  /// The two squares of the checkerboard showing an image's transparency.
  static const Color transparencyLight = Color(0xFFFFFFFF);
  static const Color transparencyDark = Color(0xFFD6D6D6);

  /// The hues of the rainbow backdrop behind an image preview, left to
  /// right.
  static const List<Color> rainbow = [
    Color(0xFFFF0000),
    Color(0xFFFF8000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
  ];

  const AppColor._();
}
