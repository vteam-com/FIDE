part of 'constants.dart';

/// Shared opacity values for emphasis, muted states, and overlays.
class AppOpacity {
  static const double prominent = 0.9;
  static const double faint = 0.4;
  static const double subtle = 0.1;
  static const double selected = 0.2;
  static const double divider = 0.3;
  static const double disabled = 0.5;
  static const double muted = 0.6;
  static const double secondaryText = 0.7;
  static const double emphasis = 0.8;

  /// Primary tint blended into the outer edge of the workspace gradient.
  static const double workspaceGlow = 0.6;

  /// Shadow blended into the workspace gradient's core to deepen contrast.
  static const double workspaceShade = 0.2;

  /// The modified image faded under the changed-pixel mask of an image
  /// diff's Difference mode, so the mask stands out but keeps its context.
  static const double imageDiffBase = 0.3;

  /// Where an image diff's Swipe divider and Onion fade start: halfway.
  static const double imageDiffHalfway = 0.5;

  const AppOpacity._();
}
