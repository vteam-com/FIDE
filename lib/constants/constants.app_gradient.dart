part of 'constants.dart';

/// Geometry of the radial workspace background gradient.
class AppGradient {
  /// Radius as a fraction of the window's shortest side; corners sit beyond
  /// it so they take the full edge glow.
  static const double workspaceRadius = 1.0;

  /// Fraction of the radius that stays at the shaded core before the glow
  /// starts.
  static const double workspaceCoreStop = 0.25;

  /// Where the glow reaches full strength.
  static const double workspaceEdgeStop = 1.0;

  const AppGradient._();
}
