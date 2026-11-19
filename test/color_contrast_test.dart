import 'package:fide/constants/constants.dart';
import 'package:fide/models/git_file_status.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/git_file_status_style.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Points sampled along the workspace gradient, from its glow to its edge.
const int _gradientSamples = 10;

/// Every text and glyph color the app draws reads on what it is drawn on,
/// at WCAG 2 level AA, in both themes.
void main() {
  /// Expects [foreground] to reach [minimum] contrast on [background].
  void expectContrast(
    Color foreground,
    Color background,
    double minimum,
    String what,
  ) {
    expect(
      AppTheme.contrast(foreground, background),
      greaterThanOrEqualTo(minimum),
      reason: what,
    );
  }

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final colorScheme = theme.colorScheme;
    final brightness = colorScheme.brightness.name;
    final surfaces = {
      'surface': colorScheme.surface,
      'surfaceContainerLowest': colorScheme.surfaceContainerLowest,
      'surfaceContainerLow': colorScheme.surfaceContainerLow,
      'surfaceContainer': colorScheme.surfaceContainer,
      'surfaceContainerHigh': colorScheme.surfaceContainerHigh,
      'surfaceContainerHighest': colorScheme.surfaceContainerHighest,
    };

    test('status colors read as text on every $brightness surface', () {
      for (final tone in StatusTone.values) {
        for (final MapEntry(key: name, value: surface) in surfaces.entries) {
          expectContrast(
            tone.readableIn(colorScheme),
            surface,
            AppTheme.minTextContrast,
            '${tone.name} on $name',
          );
        }
      }
    });

    test('text reads on every $brightness badge, message and button fill', () {
      final fills = {
        for (final tone in StatusTone.values) tone.name: tone.color,
        for (final status in GitFileStatus.values)
          if (status.badgeSymbol().isNotEmpty)
            'git ${status.name}': status.color(colorScheme),
      };
      for (final MapEntry(key: name, value: fill) in fills.entries) {
        expectContrast(
          AppTheme.onFill(fill),
          fill,
          AppTheme.minTextContrast,
          name,
        );
      }
    });

    test('every $brightness syntax color reads in the editor', () {
      final surface = colorScheme.surfaceContainerHighest;
      for (final MapEntry(key: token, value: style)
          in AppTheme.codeTheme(theme).entries) {
        final color = style.color;
        if (color == null) continue;
        expectContrast(color, surface, AppTheme.minTextContrast, token);
      }
    });

    test('the title bar and settings read on the $brightness workspace '
        'gradient', () {
      final [glow, edge] = AppTheme.workspaceColors(colorScheme);
      for (var i = 0; i <= _gradientSamples; i++) {
        final background = Color.lerp(glow, edge, i / _gradientSamples)!;
        final at = 'at step $i of $_gradientSamples, glow to edge';
        for (final MapEntry(key: name, value: text) in {
          'onSurface': colorScheme.onSurface,
          'onSurfaceVariant': colorScheme.onSurfaceVariant,
        }.entries) {
          expectContrast(
            text,
            background,
            AppTheme.minTextContrast,
            '$name text $at',
          );
        }
        for (final MapEntry(key: name, value: glyph) in {
          'primary': colorScheme.primary,
          'warning': StatusTone.warning.readableIn(colorScheme),
        }.entries) {
          expectContrast(
            glyph,
            background,
            AppTheme.minGlyphContrast,
            '$name icon $at',
          );
        }
      }
    });
  }

  test('every terminal color but black reads on its background', () {
    for (final MapEntry(key: name, value: color) in {
      'red': TerminalPalette.red,
      'green': TerminalPalette.green,
      'yellow': TerminalPalette.yellow,
      'blue': TerminalPalette.blue,
      'magenta': TerminalPalette.magenta,
      'cyan': TerminalPalette.cyan,
      'white': TerminalPalette.white,
      'brightBlack': TerminalPalette.brightBlack,
      'brightWhite': TerminalPalette.brightWhite,
    }.entries) {
      expectContrast(
        color,
        TerminalPalette.background,
        AppTheme.minTextContrast,
        name,
      );
    }
  });

  test('white goes on dark fills, black on light ones', () {
    expect(AppTheme.onFill(StatusTone.error.color), Colors.white);
    expect(AppTheme.onFill(StatusTone.warning.color), Colors.black);
  });
}
