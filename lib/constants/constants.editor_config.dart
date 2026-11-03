part of 'constants.dart';

/// Configuration constants specific to the code editor view.
class EditorConfig {
  static const double imagePreviewMaxWidthFactor = AppOpacity.emphasis;
  static const double imagePreviewMaxHeightFactor = AppOpacity.secondaryText;

  /// How far the image preview shrinks when pinched in.
  static const double imagePreviewMinScale = 0.25;

  /// How far the image preview grows when pinched out.
  static const double imagePreviewMaxScale = 8;
  static const double scrollableExtentMax = 1000000;
  static const double scrollableExtentMin = 100;
  static const double lineHeight = 20;
  static const int contextLinesAboveTarget = 3;

  const EditorConfig._();
}
