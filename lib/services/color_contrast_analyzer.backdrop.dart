part of 'color_contrast_analyzer.dart';

/// What a text or icon is drawn on in one theme: its color, how the code
/// names it, and whether it is only assumed to be the surface, as nothing
/// around the text paints a fill.
class _Backdrop {
  const _Backdrop(this.color, this.label, {this.isAssumed = false});

  /// The color drawn on, opaque.
  final WcagColor color;

  /// Whether no widget around paints a fill, so the surface is assumed.
  final bool isAssumed;

  /// How the code names it, such as `Colors.white` or `the surface`.
  final String label;

  /// What the content of [call] is drawn on in the dark theme when
  /// [isDark], else the light one: [call]'s own fill, else the nearest
  /// one around it; null when one can't be read.
  static _Backdrop? of(_Call call, _ProjectTheme theme, bool isDark) {
    final own = theme.fillOf(call, isDark);
    return own.kind == _FillKind.none
        ? _around(call.node, theme, isDark)
        : _painted(own, call.node, theme, isDark);
  }

  /// What [node] is drawn on: the fill of the nearest call around it whose
  /// arguments hold it, up to the declaration it is in, else the surface,
  /// assumed; null when that fill can't be read.
  static _Backdrop? _around(AstNode node, _ProjectTheme theme, bool isDark) {
    var child = node;
    for (
      var current = node.parent;
      current != null && current is! Declaration;
      current = current.parent
    ) {
      final call = _Call.of(current);
      if (call != null && identical(call.arguments, child)) {
        final fill = theme.fillOf(call, isDark);
        if (fill.kind != _FillKind.none) {
          return _painted(fill, current, theme, isDark);
        }
      }
      child = current;
    }
    return _Backdrop(
      theme.schemeOf(isDark)['surface']!,
      'the surface',
      isAssumed: true,
    );
  }

  /// The backdrop [fill], painted by [painter], makes: a translucent fill
  /// mixed with what is behind [painter]; null when it can't be read.
  static _Backdrop? _painted(
    _Fill fill,
    AstNode painter,
    _ProjectTheme theme,
    bool isDark,
  ) {
    final (color, label) = switch (fill) {
      _Fill(kind: _FillKind.role, :final role?, :final widget?) => (
        theme.schemeOf(isDark)[role],
        'the $widget background',
      ),
      _Fill(kind: _FillKind.color, :final expression?) => (
        theme.colors.color(expression, isDark: isDark),
        ColorContrastAnalyzer._shown(expression),
      ),
      _ => (null, ''),
    };
    if (color == null) return null;
    if (color.isOpaque) return _Backdrop(color, label);
    final under = _around(painter, theme, isDark);
    // A transparent fill shows what is behind it, by its name
    if (color.alpha == 0) return under;
    return under == null
        ? null
        : _Backdrop(color.over(under.color), label, isAssumed: under.isAssumed);
  }
}
