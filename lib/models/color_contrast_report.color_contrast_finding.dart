part of 'color_contrast_report.dart';

/// One place where a color falls below WCAG 2 level AA: what is drawn,
/// on what, how far apart they are and how far they need to be.
class ColorContrastFinding {
  /// Creates the finding at 1-based [line] of the file at absolute [path].
  const ColorContrastFinding({
    required this.kind,
    required this.path,
    required this.line,
    required this.foreground,
    required this.foregroundColor,
    required this.background,
    required this.backgroundColor,
    required this.minimum,
    this.isGlyph = false,
    this.theme,
  });

  /// Tenths in one, to show a ratio with one decimal.
  static const int _tenths = 10;

  /// What the background is, as the code names it or where it comes from,
  /// such as `Colors.white` or `the surface`.
  final String background;

  /// The background's color in the failing theme.
  final WcagColor backgroundColor;

  /// What the foreground is, as the code names it, such as `Colors.grey`
  /// or the role `onPrimary`.
  final String foreground;

  /// The foreground's color in the failing theme, as drawn: a translucent
  /// one mixed with [backgroundColor].
  final WcagColor foregroundColor;

  /// Whether the foreground is an icon or large text, which need less
  /// contrast than text.
  final bool isGlyph;

  /// Why the color falls short.
  final ColorContrastKind kind;

  /// 1-based line of the foreground in the file.
  final int line;

  /// Least contrast the foreground needs.
  final double minimum;

  /// Absolute path of the file.
  final String path;

  /// The theme the colors fail in, `light` or `dark`; null when the colors
  /// are the same in every theme the app renders.
  final String? theme;

  /// The finding in one sentence, such as `Colors.grey text (#9E9E9E) on
  /// Colors.white (#FFFFFF): 2.6:1, needs 4.5:1`.
  String get message {
    final what = switch (kind) {
      ColorContrastKind.themePair => '',
      ColorContrastKind.translucent =>
        isGlyph
            ? ' icon, faded by its opacity,'
            : ' text, faded by its opacity,',
      _ => isGlyph ? ' icon' : ' text',
    };
    final where = theme == null ? '' : ' in the $theme theme';
    return '$foreground$what (${foregroundColor.hex}) on $background '
        '(${backgroundColor.hex}): ${_ratio(ratio)}:1, needs '
        '${_ratio(minimum)}:1$where';
  }

  /// The contrast between the foreground, as drawn, and the background.
  double get ratio => foregroundColor.contrastWith(backgroundColor);

  /// [value] with one decimal, rounded down so a ratio just short of its
  /// minimum never shows as reaching it; whole numbers without one.
  static String _ratio(double value) {
    final tenths = (value * _tenths).floor();
    return tenths % _tenths == 0
        ? '${tenths ~/ _tenths}'
        : (tenths / _tenths).toStringAsFixed(1);
  }
}
