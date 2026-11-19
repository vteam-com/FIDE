import 'package:fide/models/wcag_color.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// The colors of a Material `ColorScheme` by role (`primary`, `onPrimary`,
/// `surface`…) for one brightness, without depending on Flutter: the
/// default scheme of `ThemeData()`, the one `ColorScheme.fromSeed`
/// generates, or one a project writes out, each built as Flutter builds it.
class ColorRoles {
  const ColorRoles._(this.colors, {required this.isDark});

  /// The scheme `ColorScheme(…)` builds of [given]: each role it lacks taken
  /// from the role Flutter falls back on, such as `primaryContainer` from
  /// `primary`.
  factory ColorRoles.complete(
    Map<String, WcagColor> given, {
    required bool isDark,
  }) {
    final colors = {...given};
    for (final (role, fallback) in _fallbacks) {
      if (colors[fallback] case final color? when !colors.containsKey(role)) {
        colors[role] = color;
      }
    }
    for (final MapEntry(key: role, value: argb) in _fixedDefaults.entries) {
      colors.putIfAbsent(role, () => WcagColor(argb));
    }
    return ColorRoles._(colors, isDark: isDark);
  }

  /// The scheme `ColorScheme.fromSeed` generates from [seed] as its
  /// [variant] (a `DynamicSchemeVariant` name, `tonalSpot` by default) at
  /// [contrastLevel], with the roles in [given] replacing the generated
  /// ones.
  factory ColorRoles.fromSeed(
    WcagColor seed, {
    required bool isDark,
    String variant = tonalSpot,
    double contrastLevel = 0,
    Map<String, WcagColor> given = const {},
  }) {
    final source = Hct.fromInt(seed.argb);
    final DynamicScheme scheme = switch (variant) {
      'content' => SchemeContent(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'expressive' => SchemeExpressive(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'fidelity' => SchemeFidelity(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'fruitSalad' => SchemeFruitSalad(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'monochrome' => SchemeMonochrome(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'neutral' => SchemeNeutral(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'rainbow' => SchemeRainbow(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      'vibrant' => SchemeVibrant(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
      _ => SchemeTonalSpot(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: contrastLevel,
      ),
    };
    return ColorRoles._({
      for (final MapEntry(key: role, value: color) in _dynamicColors.entries)
        role: WcagColor(color.getArgb(scheme)),
      ...given,
    }, isDark: isDark);
  }

  /// The scheme `ColorScheme.light()` or `ColorScheme.dark()` builds, the
  /// Material 2 defaults, with the roles in [given] replacing them.
  factory ColorRoles.legacy(
    Map<String, WcagColor> given, {
    required bool isDark,
  }) => ColorRoles.complete({
    for (final MapEntry(key: role, value: argb)
        in (isDark ? _legacyDark : _legacyLight).entries)
      role: WcagColor(argb),
    ...given,
  }, isDark: isDark);

  /// Material 3's default scheme, the one `ThemeData()` uses without a
  /// color scheme or seed.
  factory ColorRoles.material3({required bool isDark}) => ColorRoles._({
    for (final MapEntry(key: role, value: argb)
        in (isDark ? _material3Dark : _material3Light).entries)
      role: WcagColor(argb),
  }, isDark: isDark);

  /// The `DynamicSchemeVariant` `ColorScheme.fromSeed` uses by default.
  static const String tonalSpot = 'tonalSpot';

  /// The on-colors of the scheme and the fill each is drawn on as text,
  /// as (fill, on-color) pairs.
  static const List<(String, String)> pairs = [
    ('primary', 'onPrimary'),
    ('primaryContainer', 'onPrimaryContainer'),
    ('primaryFixed', 'onPrimaryFixed'),
    ('primaryFixed', 'onPrimaryFixedVariant'),
    ('secondary', 'onSecondary'),
    ('secondaryContainer', 'onSecondaryContainer'),
    ('secondaryFixed', 'onSecondaryFixed'),
    ('secondaryFixed', 'onSecondaryFixedVariant'),
    ('tertiary', 'onTertiary'),
    ('tertiaryContainer', 'onTertiaryContainer'),
    ('tertiaryFixed', 'onTertiaryFixed'),
    ('tertiaryFixed', 'onTertiaryFixedVariant'),
    ('error', 'onError'),
    ('errorContainer', 'onErrorContainer'),
    ('surface', 'onSurface'),
    ('surface', 'onSurfaceVariant'),
    ('surfaceContainerHighest', 'onSurface'),
    ('surfaceContainerHighest', 'onSurfaceVariant'),
    ('inverseSurface', 'onInverseSurface'),
  ];

  /// Each role Flutter's `ColorScheme(…)` constructor fills from another
  /// when it is not given, in an order where the other is filled first.
  static const List<(String, String)> _fallbacks = [
    ('background', 'surface'),
    ('onBackground', 'onSurface'),
    ('primaryContainer', 'primary'),
    ('onPrimaryContainer', 'onPrimary'),
    ('primaryFixed', 'primary'),
    ('primaryFixedDim', 'primary'),
    ('onPrimaryFixed', 'onPrimary'),
    ('onPrimaryFixedVariant', 'onPrimary'),
    ('secondaryContainer', 'secondary'),
    ('onSecondaryContainer', 'onSecondary'),
    ('secondaryFixed', 'secondary'),
    ('secondaryFixedDim', 'secondary'),
    ('onSecondaryFixed', 'onSecondary'),
    ('onSecondaryFixedVariant', 'onSecondary'),
    ('tertiary', 'secondary'),
    ('onTertiary', 'onSecondary'),
    ('tertiaryContainer', 'tertiary'),
    ('onTertiaryContainer', 'onTertiary'),
    ('tertiaryFixed', 'tertiary'),
    ('tertiaryFixedDim', 'tertiary'),
    ('onTertiaryFixed', 'onTertiary'),
    ('onTertiaryFixedVariant', 'onTertiary'),
    ('errorContainer', 'error'),
    ('onErrorContainer', 'onError'),
    ('surfaceVariant', 'surface'),
    ('surfaceDim', 'surface'),
    ('surfaceBright', 'surface'),
    ('surfaceContainerLowest', 'surface'),
    ('surfaceContainerLow', 'surface'),
    ('surfaceContainer', 'surface'),
    ('surfaceContainerHigh', 'surface'),
    ('surfaceContainerHighest', 'surface'),
    ('onSurfaceVariant', 'onSurface'),
    ('outline', 'onBackground'),
    ('outlineVariant', 'onBackground'),
    ('inverseSurface', 'onSurface'),
    ('onInverseSurface', 'surface'),
    ('inversePrimary', 'onPrimary'),
    ('surfaceTint', 'primary'),
  ];

  /// Roles Flutter's `ColorScheme(…)` constructor sets to a fixed color
  /// when they are not given, as 0xAARRGGBB.
  static const Map<String, int> _fixedDefaults = {
    'shadow': 0xFF000000,
    'scrim': 0xFF000000,
  };

  /// The dynamic color `ColorScheme.fromSeed` reads each role from;
  /// `surfaceTint` is its primary, as Flutter sets it.
  static final Map<String, DynamicColor> _dynamicColors = {
    'primary': MaterialDynamicColors.primary,
    'onPrimary': MaterialDynamicColors.onPrimary,
    'primaryContainer': MaterialDynamicColors.primaryContainer,
    'onPrimaryContainer': MaterialDynamicColors.onPrimaryContainer,
    'primaryFixed': MaterialDynamicColors.primaryFixed,
    'primaryFixedDim': MaterialDynamicColors.primaryFixedDim,
    'onPrimaryFixed': MaterialDynamicColors.onPrimaryFixed,
    'onPrimaryFixedVariant': MaterialDynamicColors.onPrimaryFixedVariant,
    'secondary': MaterialDynamicColors.secondary,
    'onSecondary': MaterialDynamicColors.onSecondary,
    'secondaryContainer': MaterialDynamicColors.secondaryContainer,
    'onSecondaryContainer': MaterialDynamicColors.onSecondaryContainer,
    'secondaryFixed': MaterialDynamicColors.secondaryFixed,
    'secondaryFixedDim': MaterialDynamicColors.secondaryFixedDim,
    'onSecondaryFixed': MaterialDynamicColors.onSecondaryFixed,
    'onSecondaryFixedVariant': MaterialDynamicColors.onSecondaryFixedVariant,
    'tertiary': MaterialDynamicColors.tertiary,
    'onTertiary': MaterialDynamicColors.onTertiary,
    'tertiaryContainer': MaterialDynamicColors.tertiaryContainer,
    'onTertiaryContainer': MaterialDynamicColors.onTertiaryContainer,
    'tertiaryFixed': MaterialDynamicColors.tertiaryFixed,
    'tertiaryFixedDim': MaterialDynamicColors.tertiaryFixedDim,
    'onTertiaryFixed': MaterialDynamicColors.onTertiaryFixed,
    'onTertiaryFixedVariant': MaterialDynamicColors.onTertiaryFixedVariant,
    'error': MaterialDynamicColors.error,
    'onError': MaterialDynamicColors.onError,
    'errorContainer': MaterialDynamicColors.errorContainer,
    'onErrorContainer': MaterialDynamicColors.onErrorContainer,
    'outline': MaterialDynamicColors.outline,
    'outlineVariant': MaterialDynamicColors.outlineVariant,
    'surface': MaterialDynamicColors.surface,
    'onSurface': MaterialDynamicColors.onSurface,
    'surfaceDim': MaterialDynamicColors.surfaceDim,
    'surfaceBright': MaterialDynamicColors.surfaceBright,
    'surfaceContainerLowest': MaterialDynamicColors.surfaceContainerLowest,
    'surfaceContainerLow': MaterialDynamicColors.surfaceContainerLow,
    'surfaceContainer': MaterialDynamicColors.surfaceContainer,
    'surfaceContainerHigh': MaterialDynamicColors.surfaceContainerHigh,
    'surfaceContainerHighest': MaterialDynamicColors.surfaceContainerHighest,
    'onSurfaceVariant': MaterialDynamicColors.onSurfaceVariant,
    'inverseSurface': MaterialDynamicColors.inverseSurface,
    'onInverseSurface': MaterialDynamicColors.inverseOnSurface,
    'inversePrimary': MaterialDynamicColors.inversePrimary,
    'shadow': MaterialDynamicColors.shadow,
    'scrim': MaterialDynamicColors.scrim,
    'surfaceTint': MaterialDynamicColors.primary,
    'background': MaterialDynamicColors.background,
    'onBackground': MaterialDynamicColors.onBackground,
    'surfaceVariant': MaterialDynamicColors.surfaceVariant,
  };

  /// The Material 2 defaults of `ColorScheme.light()`, as 0xAARRGGBB.
  static const Map<String, int> _legacyLight = {
    'primary': 0xFF6200EE,
    'onPrimary': 0xFFFFFFFF,
    'secondary': 0xFF03DAC6,
    'onSecondary': 0xFF000000,
    'error': 0xFFB00020,
    'onError': 0xFFFFFFFF,
    'surface': 0xFFFFFFFF,
    'onSurface': 0xFF000000,
  };

  /// The Material 2 defaults of `ColorScheme.dark()`, as 0xAARRGGBB.
  static const Map<String, int> _legacyDark = {
    'primary': 0xFFBB86FC,
    'onPrimary': 0xFF000000,
    'secondary': 0xFF03DAC6,
    'onSecondary': 0xFF000000,
    'error': 0xFFCF6679,
    'onError': 0xFF000000,
    'surface': 0xFF121212,
    'onSurface': 0xFFFFFFFF,
  };

  /// Material 3's default light scheme, as 0xAARRGGBB; generated from the
  /// Flutter SDK's `theme_data.dart`.
  static const Map<String, int> _material3Light = {
    'primary': 0xFF6750A4,
    'onPrimary': 0xFFFFFFFF,
    'primaryContainer': 0xFFEADDFF,
    'onPrimaryContainer': 0xFF4F378B,
    'primaryFixed': 0xFFEADDFF,
    'primaryFixedDim': 0xFFD0BCFF,
    'onPrimaryFixed': 0xFF21005D,
    'onPrimaryFixedVariant': 0xFF4F378B,
    'secondary': 0xFF625B71,
    'onSecondary': 0xFFFFFFFF,
    'secondaryContainer': 0xFFE8DEF8,
    'onSecondaryContainer': 0xFF4A4458,
    'secondaryFixed': 0xFFE8DEF8,
    'secondaryFixedDim': 0xFFCCC2DC,
    'onSecondaryFixed': 0xFF1D192B,
    'onSecondaryFixedVariant': 0xFF4A4458,
    'tertiary': 0xFF7D5260,
    'onTertiary': 0xFFFFFFFF,
    'tertiaryContainer': 0xFFFFD8E4,
    'onTertiaryContainer': 0xFF633B48,
    'tertiaryFixed': 0xFFFFD8E4,
    'tertiaryFixedDim': 0xFFEFB8C8,
    'onTertiaryFixed': 0xFF31111D,
    'onTertiaryFixedVariant': 0xFF633B48,
    'error': 0xFFB3261E,
    'onError': 0xFFFFFFFF,
    'errorContainer': 0xFFF9DEDC,
    'onErrorContainer': 0xFF8C1D18,
    'background': 0xFFFEF7FF,
    'onBackground': 0xFF1D1B20,
    'surface': 0xFFFEF7FF,
    'surfaceBright': 0xFFFEF7FF,
    'surfaceContainerLowest': 0xFFFFFFFF,
    'surfaceContainerLow': 0xFFF7F2FA,
    'surfaceContainer': 0xFFF3EDF7,
    'surfaceContainerHigh': 0xFFECE6F0,
    'surfaceContainerHighest': 0xFFE6E0E9,
    'surfaceDim': 0xFFDED8E1,
    'onSurface': 0xFF1D1B20,
    'surfaceVariant': 0xFFE7E0EC,
    'onSurfaceVariant': 0xFF49454F,
    'outline': 0xFF79747E,
    'outlineVariant': 0xFFCAC4D0,
    'shadow': 0xFF000000,
    'scrim': 0xFF000000,
    'inverseSurface': 0xFF322F35,
    'onInverseSurface': 0xFFF5EFF7,
    'inversePrimary': 0xFFD0BCFF,
    'surfaceTint': 0xFF6750A4,
  };

  /// Material 3's default dark scheme, as 0xAARRGGBB.
  static const Map<String, int> _material3Dark = {
    'primary': 0xFFD0BCFF,
    'onPrimary': 0xFF381E72,
    'primaryContainer': 0xFF4F378B,
    'onPrimaryContainer': 0xFFEADDFF,
    'primaryFixed': 0xFFEADDFF,
    'primaryFixedDim': 0xFFD0BCFF,
    'onPrimaryFixed': 0xFF21005D,
    'onPrimaryFixedVariant': 0xFF4F378B,
    'secondary': 0xFFCCC2DC,
    'onSecondary': 0xFF332D41,
    'secondaryContainer': 0xFF4A4458,
    'onSecondaryContainer': 0xFFE8DEF8,
    'secondaryFixed': 0xFFE8DEF8,
    'secondaryFixedDim': 0xFFCCC2DC,
    'onSecondaryFixed': 0xFF1D192B,
    'onSecondaryFixedVariant': 0xFF4A4458,
    'tertiary': 0xFFEFB8C8,
    'onTertiary': 0xFF492532,
    'tertiaryContainer': 0xFF633B48,
    'onTertiaryContainer': 0xFFFFD8E4,
    'tertiaryFixed': 0xFFFFD8E4,
    'tertiaryFixedDim': 0xFFEFB8C8,
    'onTertiaryFixed': 0xFF31111D,
    'onTertiaryFixedVariant': 0xFF633B48,
    'error': 0xFFF2B8B5,
    'onError': 0xFF601410,
    'errorContainer': 0xFF8C1D18,
    'onErrorContainer': 0xFFF9DEDC,
    'background': 0xFF141218,
    'onBackground': 0xFFE6E0E9,
    'surface': 0xFF141218,
    'surfaceBright': 0xFF3B383E,
    'surfaceContainerLowest': 0xFF0F0D13,
    'surfaceContainerLow': 0xFF1D1B20,
    'surfaceContainer': 0xFF211F26,
    'surfaceContainerHigh': 0xFF2B2930,
    'surfaceContainerHighest': 0xFF36343B,
    'surfaceDim': 0xFF141218,
    'onSurface': 0xFFE6E0E9,
    'surfaceVariant': 0xFF49454F,
    'onSurfaceVariant': 0xFFCAC4D0,
    'outline': 0xFF938F99,
    'outlineVariant': 0xFF49454F,
    'shadow': 0xFF000000,
    'scrim': 0xFF000000,
    'inverseSurface': 0xFFE6E0E9,
    'onInverseSurface': 0xFF322F35,
    'inversePrimary': 0xFF6750A4,
    'surfaceTint': 0xFFD0BCFF,
  };

  /// The scheme's colors by role.
  final Map<String, WcagColor> colors;

  /// Whether the scheme is a dark one.
  final bool isDark;

  /// The color of [role]; null when the scheme has no such role.
  WcagColor? operator [](String role) => colors[role];

  /// The scheme with the roles in [given] replaced, as Flutter's
  /// `ColorScheme.copyWith` does.
  ColorRoles copyWith(Map<String, WcagColor> given) =>
      ColorRoles._({...colors, ...given}, isDark: isDark);

  /// Whether [name] is a role of a `ColorScheme`.
  static bool isRole(String name) => _dynamicColors.containsKey(name);
}
