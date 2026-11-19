part of 'color_contrast_report.dart';

/// The color scheme of one theme the app renders: its colors, how it is
/// made, the roles the code sets itself, and where it is defined.
class ColorSchemeSummary {
  /// Creates the summary of the [theme] theme's scheme of [roles].
  const ColorSchemeSummary({
    required this.theme,
    required this.roles,
    required this.origin,
    this.givenRoles = const [],
    this.path,
    this.line,
  });

  /// How the scheme is made, such as `Generated from the seed
  /// Colors.indigo` or `Material 3's default`.
  final String origin;

  /// The roles the code sets itself, such as `primary`, in its order.
  final List<String> givenRoles;

  /// 1-based line where the scheme is defined; null for a default one.
  final int? line;

  /// Absolute path of the file defining the scheme; null for a default
  /// one.
  final String? path;

  /// The scheme's colors.
  final ColorRoles roles;

  /// The theme, `light` or `dark`.
  final String theme;

  /// Whether the theme is the dark one.
  bool get isDark => roles.isDark;
}
