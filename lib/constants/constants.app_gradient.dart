part of 'constants.dart';

/// Geometry of the radial gradients: the workspace background and the image
/// preview's blend backdrop.
class AppGradient {
  /// Radius of each spot of the image preview's blend backdrop, as a
  /// fraction of the preview's shortest side, wide enough for neighbors to
  /// overlap and melt into one another.
  static const double blendSpotRadius = 0.5;

  /// Radius as a fraction of the window's shortest side; corners sit beyond
  /// it so they take the full edge shade.
  static const double workspaceRadius = 1.0;

  /// Fraction of the radius that stays at the glowing core before the
  /// shade starts.
  static const double workspaceCoreStop = 0.25;

  /// Where the shade reaches full strength.
  static const double workspaceEdgeStop = 1.0;

  const AppGradient._();
}
