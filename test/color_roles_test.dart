import 'package:fide/models/color_roles.dart';
import 'package:fide/models/material_palette.dart';
import 'package:fide/models/wcag_color.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Every role of [scheme] by the name the analyzer reads it by.
Map<String, Color> _rolesOf(ColorScheme scheme) => {
  'primary': scheme.primary,
  'onPrimary': scheme.onPrimary,
  'primaryContainer': scheme.primaryContainer,
  'onPrimaryContainer': scheme.onPrimaryContainer,
  'primaryFixed': scheme.primaryFixed,
  'primaryFixedDim': scheme.primaryFixedDim,
  'onPrimaryFixed': scheme.onPrimaryFixed,
  'onPrimaryFixedVariant': scheme.onPrimaryFixedVariant,
  'secondary': scheme.secondary,
  'onSecondary': scheme.onSecondary,
  'secondaryContainer': scheme.secondaryContainer,
  'onSecondaryContainer': scheme.onSecondaryContainer,
  'secondaryFixed': scheme.secondaryFixed,
  'secondaryFixedDim': scheme.secondaryFixedDim,
  'onSecondaryFixed': scheme.onSecondaryFixed,
  'onSecondaryFixedVariant': scheme.onSecondaryFixedVariant,
  'tertiary': scheme.tertiary,
  'onTertiary': scheme.onTertiary,
  'tertiaryContainer': scheme.tertiaryContainer,
  'onTertiaryContainer': scheme.onTertiaryContainer,
  'tertiaryFixed': scheme.tertiaryFixed,
  'tertiaryFixedDim': scheme.tertiaryFixedDim,
  'onTertiaryFixed': scheme.onTertiaryFixed,
  'onTertiaryFixedVariant': scheme.onTertiaryFixedVariant,
  'error': scheme.error,
  'onError': scheme.onError,
  'errorContainer': scheme.errorContainer,
  'onErrorContainer': scheme.onErrorContainer,
  'outline': scheme.outline,
  'outlineVariant': scheme.outlineVariant,
  'surface': scheme.surface,
  'onSurface': scheme.onSurface,
  'surfaceDim': scheme.surfaceDim,
  'surfaceBright': scheme.surfaceBright,
  'surfaceContainerLowest': scheme.surfaceContainerLowest,
  'surfaceContainerLow': scheme.surfaceContainerLow,
  'surfaceContainer': scheme.surfaceContainer,
  'surfaceContainerHigh': scheme.surfaceContainerHigh,
  'surfaceContainerHighest': scheme.surfaceContainerHighest,
  'onSurfaceVariant': scheme.onSurfaceVariant,
  'inverseSurface': scheme.inverseSurface,
  'onInverseSurface': scheme.onInverseSurface,
  'inversePrimary': scheme.inversePrimary,
  'shadow': scheme.shadow,
  'scrim': scheme.scrim,
  'surfaceTint': scheme.surfaceTint,
};

/// Expects [roles] to hold every color of [scheme].
void _expectSame(ColorRoles roles, ColorScheme scheme) {
  for (final MapEntry(key: role, value: color) in _rolesOf(scheme).entries) {
    expect(roles[role], WcagColor(color.toARGB32()), reason: role);
  }
  expect(roles.isDark, scheme.brightness == Brightness.dark);
}

/// The analyzer's tables and color math, checked against Flutter's own.
void main() {
  for (final isDark in [false, true]) {
    final brightness = isDark ? Brightness.dark : Brightness.light;

    test('the $brightness Material 3 default is ThemeData()\'s', () {
      _expectSame(
        ColorRoles.material3(isDark: isDark),
        ThemeData(brightness: brightness).colorScheme,
      );
    });

    test('a $brightness scheme from a seed is ColorScheme.fromSeed\'s', () {
      for (final seed in [Colors.teal, Colors.amber, const Color(0xFF3D5AFE)]) {
        _expectSame(
          ColorRoles.fromSeed(WcagColor(seed.toARGB32()), isDark: isDark),
          ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
        );
      }
      _expectSame(
        ColorRoles.fromSeed(
          WcagColor(Colors.pink.toARGB32()),
          isDark: isDark,
          variant: 'vibrant',
          contrastLevel: 0.5,
        ),
        ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
          contrastLevel: 0.5,
        ),
      );
    });
  }

  test('ColorScheme.light() and a written-out scheme fill roles alike', () {
    _expectSame(
      ColorRoles.legacy(const {}, isDark: false),
      const ColorScheme.light(),
    );
    _expectSame(
      ColorRoles.legacy(const {}, isDark: true),
      const ColorScheme.dark(),
    );
    _expectSame(
      ColorRoles.complete({
        'primary': const WcagColor(0xFF00695C),
        'onPrimary': const WcagColor(0xFFFFFFFF),
        'secondary': const WcagColor(0xFFFFB300),
        'onSecondary': const WcagColor(0xFF000000),
        'error': const WcagColor(0xFFB00020),
        'onError': const WcagColor(0xFFFFFFFF),
        'surface': const WcagColor(0xFFFAFAFA),
        'onSurface': const WcagColor(0xFF212121),
      }, isDark: false),
      const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF00695C),
        onPrimary: Color(0xFFFFFFFF),
        secondary: Color(0xFFFFB300),
        onSecondary: Color(0xFF000000),
        error: Color(0xFFB00020),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFAFAFA),
        onSurface: Color(0xFF212121),
      ),
    );
  });

  test('the palette is Material\'s Colors', () {
    final expected = <String, Color>{
      'black54': Colors.black54,
      'white70': Colors.white70,
      'grey': Colors.grey,
      'blueGrey': Colors.blueGrey,
      'deepOrangeAccent': Colors.deepOrangeAccent,
    };
    for (final MapEntry(key: name, value: color) in expected.entries) {
      expect(MaterialPalette.colors[name], color.toARGB32(), reason: name);
    }
    expect(MaterialPalette.shades['grey']![850], Colors.grey[850]!.toARGB32());
    expect(
      MaterialPalette.shades['redAccent']![700],
      Colors.redAccent[700]!.toARGB32(),
    );
  });

  test('contrast and translucency are computed as Flutter computes them', () {
    const pairs = [
      (Colors.grey, Colors.white),
      (Color(0xFF767676), Colors.white),
      (Colors.black, Colors.white),
      (Color(0xFF1D1B20), Color(0xFFFEF7FF)),
    ];
    for (final (foreground, background) in pairs) {
      expect(
        WcagColor(foreground.toARGB32())
            .contrastWith(WcagColor(background.toARGB32())),
        closeTo(AppTheme.contrast(foreground, background), 1e-9),
      );
    }
    // An 8-bit alpha, as the analyzer reads colors
    final faded = Colors.black.withAlpha(0x80);
    expect(
      WcagColor(faded.toARGB32()).over(const WcagColor(0xFFFFFFFF)),
      WcagColor(Color.alphaBlend(faded, Colors.white).toARGB32()),
    );
  });
}
