// ignore: fcheck_dead_code

import 'package:fide/constants/constants.dart';
import 'package:fide/models/wcag_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

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

  /// Text and glyphs drawn on [fill], such as a badge, a message or a red
  /// Stop button: white, the same on every fill, unless white falls short
  /// of [minTextContrast] there, as on the warning orange, then black.
  static Color onFill(Color fill) =>
      contrast(Colors.white, fill) >= minTextContrast
      ? Colors.white
      : Colors.black;

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
        thickness: AppSize.borderThin,
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
      // Every tooltip waits alike before showing, as the platform's do, so
      // moving the pointer across rows and buttons doesn't flash them
      tooltipTheme: const TooltipThemeData(
        waitDuration: AppDuration.tooltipWait,
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
  static const double minTextContrast = WcagColor.minTextContrast;

  /// Least contrast ratio of an icon or other glyph that carries meaning
  /// against its background, WCAG 2 level AA for non-text content.
  static const double minGlyphContrast = WcagColor.minLargeContrast;

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
    while (contrast(hsl.toColor(), surface) < minTextContrast) {
      final lightness = (hsl.lightness + step).clamp(0.0, 1.0);
      if (lightness == hsl.lightness) break;
      hsl = hsl.withLightness(lightness);
    }
    return hsl.toColor();
  }

  /// The code editor's syntax highlighting: the highlight.js Atom One
  /// theme of [theme]'s brightness with [AppTextStyle.codeTokens] layered
  /// on top, every color made [readable], as some of Atom One Light's are
  /// too pale to read.
  static Map<String, TextStyle> codeTheme(ThemeData theme) => {
    for (final MapEntry(:key, :value) in {
      ...(theme.brightness == Brightness.dark
          ? atomOneDarkTheme
          : atomOneLightTheme),
      ...AppTextStyle.codeTokens(theme),
    }.entries)
      key: switch (value.color) {
        final color? => value.copyWith(
          color: readable(color, theme.colorScheme),
        ),
        null => value,
      },
  };

  /// The WCAG contrast ratio between [a] and [b], from 1 to 21, as the
  /// color contrast analyzer measures a project's colors.
  static double contrast(Color a, Color b) =>
      WcagColor(a.toARGB32()).contrastWith(WcagColor(b.toARGB32()));

  /// The fill of the selected entry of a list, tree or grid.
  static Color selectedFill(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: AppOpacity.divider);

  /// Radial gradient the workspace panel islands float on.
  ///
  /// The panels' surface tinted with the primary color, strongest in a
  /// glow at [center], the window's top center by default: the light
  /// theme's primary darkens it to a blue, the dark theme's brightens it,
  /// so the gaps between islands read clearly in both modes.
  static BoxDecoration workspaceBackground(
    BuildContext context, {
    Alignment center = Alignment.topCenter,
  }) {
    return BoxDecoration(
      gradient: RadialGradient(
        center: center,
        radius: AppGradient.workspaceRadius,
        colors: workspaceColors(Theme.of(context).colorScheme),
        stops: const [
          AppGradient.workspaceCoreStop,
          AppGradient.workspaceEdgeStop,
        ],
      ),
    );
  }

  /// The [workspaceBackground] gradient's two colors: its glow, then its
  /// edge.
  ///
  /// The title bar and the settings draw straight on them, so both stay
  /// subtle enough for text and icons to read on either.
  static List<Color> workspaceColors(ColorScheme colorScheme) {
    final light = colorScheme.brightness == Brightness.light;
    Color tint(double alpha) => Color.alphaBlend(
      colorScheme.primary.withValues(alpha: alpha),
      colorScheme.surface,
    );
    return [
      tint(
        light ? AppOpacity.workspaceGlowLight : AppOpacity.workspaceGlowDark,
      ),
      tint(
        light ? AppOpacity.workspaceEdgeLight : AppOpacity.workspaceEdgeDark,
      ),
    ];
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
