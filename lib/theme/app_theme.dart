// ignore: fcheck_dead_code

import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// Represents `AppTheme`.
class AppTheme {
  // Single seed color for consistent theming
  static const Color _seedColor = Colors.blue;

  /// Semantic status colors for consistent use across BadgeStatus, MessageBox, and LocalizationPanel
  /// These colors work with both light and dark themes
  static const Color successColor = Color(
    0xFF1B5E20,
  ); // Dark green for success states
  static const Color warningColor = Color(
    0xFFF57C00,
  ); // Orange for warning states, kept clear of the error red
  static const Color errorColor = Color(
    0xFFD32F2F,
  ); // Dark red for error states
  static const Color infoColor = Color(0xFF1976D2); // Dark blue for info states
  static const Color neutralColor = Color(
    0xFF616161,
  ); // Dark grey for neutral states

  /// Text and glyphs drawn on a status color, such as a badge or a message.
  static Color get onStatusColor => Colors.white.withAlpha(AppAlpha.badgeText);

  /// Fill behind content marked as an error, such as a broken dependency.
  static Color get errorBackground => errorColor.withAlpha(AppAlpha.badgeFill);

  /// Builds the shared theme configuration used by both theme modes.
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color popupBorderColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return ThemeData.from(
      colorScheme: colorScheme,
      useMaterial3: true,
    ).copyWith(
      // One color for every line: dividers, header strips and box outlines
      dividerColor: colorScheme.outline.withValues(alpha: AppOpacity.divider),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
      ),
      // One look for every TabBar: full-width underline, primary when selected
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTextStyle.badgeStrong,
        unselectedLabelStyle: AppTextStyle.badge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyle.title,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          side: BorderSide(color: popupBorderColor, width: AppSize.borderThin),
        ),
        elevation: AppSpacing.small,
      ),
    );
  }

  /// Builds the application's light theme.
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      popupBorderColor: AppColor.popupBorderLight,
    );
  }

  /// Builds the application's dark theme.
  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      popupBorderColor: AppColor.popupBorderDark,
    );
  }

  /// Least contrast ratio of text against its background, WCAG 2 level AA.
  static const double minTextContrast = 4.5;

  /// Luminance WCAG adds to both colors of a contrast ratio, for flare.
  static const double _contrastFlare = 0.05;

  /// Lightness [readable] moves a color by per step.
  static const double _lightnessStep = 0.05;

  /// [color] with its hue and saturation kept and its lightness moved,
  /// away from the surface, until text in it reaches [minTextContrast]
  /// on every surface of [colorScheme].
  ///
  /// The status colors are mid-dark shades: they read on light surfaces
  /// but not on dark ones, and some not on white either. Draw status text
  /// and glyphs straight on a surface in this color; badge fills keep the
  /// status color itself.
  static Color readable(Color color, ColorScheme colorScheme) {
    // The surface tone closest to text colors, so text reads on all of
    // them: the darkest in light mode, the lightest in dark mode.
    final surface = colorScheme.surfaceContainerHighest;
    final step = colorScheme.brightness == Brightness.dark
        ? _lightnessStep
        : -_lightnessStep;
    var hsl = HSLColor.fromColor(color);
    while (_contrast(hsl.toColor(), surface) < minTextContrast) {
      final lightness = (hsl.lightness + step).clamp(0.0, 1.0);
      if (lightness == hsl.lightness) break;
      hsl = hsl.withLightness(lightness);
    }
    return hsl.toColor();
  }

  /// The WCAG contrast ratio between [a] and [b], from 1 to 21.
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance() + _contrastFlare;
    final lb = b.computeLuminance() + _contrastFlare;
    return la > lb ? la / lb : lb / la;
  }

  /// The fill of the selected entry of a list, tree or grid.
  static Color selectedFill(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: AppOpacity.divider);

  /// Radial gradient the workspace panel islands float on.
  ///
  /// A shaded core, darker than every surface tone, opens out to a primary
  /// glow at the window edges, so the gaps between islands read clearly in
  /// both modes.
  static BoxDecoration workspaceBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).brightness == Brightness.light
        ? colorScheme.surfaceDim
        : colorScheme.surfaceContainerLowest;
    return BoxDecoration(
      gradient: RadialGradient(
        radius: AppGradient.workspaceRadius,
        colors: [
          Color.alphaBlend(
            colorScheme.shadow.withValues(alpha: AppOpacity.workspaceShade),
            base,
          ),
          Color.alphaBlend(
            colorScheme.primary.withValues(alpha: AppOpacity.workspaceGlow),
            base,
          ),
        ],
        stops: const [
          AppGradient.workspaceCoreStop,
          AppGradient.workspaceEdgeStop,
        ],
      ),
    );
  }

  /// Vertical surface gradient behind the full-screen welcome, loading and
  /// create-project views.
  static BoxDecoration screenBackground(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.surface,
          colorScheme.surfaceContainerHighest.withValues(
            alpha: AppOpacity.divider,
          ),
        ],
      ),
    );
  }
}
