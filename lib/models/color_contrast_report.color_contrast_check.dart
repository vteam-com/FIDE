part of 'color_contrast_report.dart';

/// One element judged against WCAG 2 level AA: what is drawn, on what,
/// how far apart they are and, when it falls short, why.
class ColorContrastCheck {
  /// Creates the check at 1-based [line] of the file at absolute [path].
  const ColorContrastCheck({
    required this.element,
    required this.path,
    required this.line,
    required this.foreground,
    required this.foregroundColor,
    required this.background,
    required this.backgroundColor,
    this.failure,
    this.theme,
  });

  /// Tenths in one, to show a ratio with one decimal.
  static const int _tenths = 10;

  /// What the background is, as the code names it or where it comes from,
  /// such as `Colors.white` or `the surface`.
  final String background;

  /// The background's color in the theme judged.
  final WcagColor backgroundColor;

  /// What kind of element is judged, which sets the contrast it needs.
  final ColorContrastElement element;

  /// Why the colors fall below WCAG 2 level AA; null when they pass.
  final ColorContrastKind? failure;

  /// What the foreground is, as the code names it, such as `Colors.grey`
  /// or the role `onPrimary`.
  final String foreground;

  /// The foreground's color in the theme judged, as drawn: a translucent
  /// one mixed with [backgroundColor].
  final WcagColor foregroundColor;

  /// 1-based line of the foreground in the file.
  final int line;

  /// Absolute path of the file.
  final String path;

  /// The theme judged, `light` or `dark`, the one the colors fare worst
  /// in; null when they are the same in every theme the app renders.
  final String? theme;

  /// The check in one sentence, such as `Colors.grey text (#9E9E9E) on
  /// Colors.white (#FFFFFF): 2.6:1, needs 4.5:1`.
  String get message {
    final noun = element.noun;
    final what = switch (failure) {
      _ when noun.isEmpty => '',
      ColorContrastKind.translucent => ' $noun, faded by its opacity,',
      _ => ' $noun',
    };
    final where = theme == null ? '' : ' in the $theme theme';
    return '$foreground$what (${foregroundColor.hex}) on $background '
        '(${backgroundColor.hex}): ${_ratio(ratio)}:1, needs '
        '${_ratio(minimum)}:1$where';
  }

  /// Least contrast the element needs.
  double get minimum => element.minimum;

  /// Whether the colors reach WCAG 2 level AA.
  bool get passes => failure == null;

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
