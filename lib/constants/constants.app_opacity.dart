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

  /// Primary tint over the panel surface at the light workspace gradient's
  /// core, darkening it to a blue: as dark as the title bar's and the
  /// settings' dim text allows, reading at AA on it.
  static const double workspaceGlowLight = 0.44;

  /// Primary tint over the panel surface at the dark workspace gradient's
  /// core, brightening it to a blue the title bar's icons still read on.
  static const double workspaceGlowDark = 0.3;

  /// Primary tint over the panel surface at the light workspace gradient's
  /// edge: as far in lightness from the panels as the dark theme's edge,
  /// so the gradient from the glow shows as plainly in both themes.
  static const double workspaceEdgeLight = 0.19;

  /// Primary tint over the panel surface at the dark workspace gradient's
  /// edge: enough to keep the gaps brighter than the panels.
  static const double workspaceEdgeDark = 0.12;

  /// The modified image faded under the changed-pixel mask of an image
  /// diff's Difference mode, so the mask stands out but keeps its context.
  static const double imageDiffBase = 0.3;

  /// Where an image diff's Swipe divider and Onion fade start: halfway.
  static const double imageDiffHalfway = 0.5;

  const AppOpacity._();
}
