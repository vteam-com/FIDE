part of 'color_contrast_analyzer.dart';

/// A foreground color in one theme, with what it is drawn on there.
typedef _Sample = ({WcagColor color, _Backdrop backdrop, bool isDark});

/// Finds in one file each text and icon color the code gives, and judges
/// it against what it is drawn on in each theme the app renders.
class _ContrastVisitor extends RecursiveAstVisitor<void> {
  _ContrastVisitor(this._file, this._theme);

  /// Widgets whose `color` is the color of their icon.
  static const Set<String> _icons = {'Icon', 'IconButton', 'ImageIcon'};

  /// Widgets whose foreground is an icon: their `foregroundColor` colors a
  /// glyph.
  static const Set<String> _iconWidgets = {
    'FloatingActionButton',
    'IconButton',
  };

  /// Named arguments that color the text of the widget given them.
  static const Set<String> _textColors = {
    'foregroundColor',
    'labelColor',
    'selectedItemColor',
    'textColor',
    'unselectedItemColor',
    'unselectedLabelColor',
  };

  /// The named argument coloring the icons of the widget given it.
  static const String _iconColor = 'iconColor';

  /// Font weights WCAG counts as bold.
  static const Set<String> _boldWeights = {
    'FontWeight.bold',
    'FontWeight.w700',
    'FontWeight.w800',
    'FontWeight.w900',
  };

  /// Logical pixels per typographic point, as CSS counts them.
  static const double _pixelsPerPoint = 4 / 3;

  /// Sizes WCAG counts as large text, in points: plain, then bold.
  static const double _largePoints = 18;

  static const double _largeBoldPoints = 14;

  /// Text theme styles WCAG counts as large: the display and headline
  /// ones.
  static final RegExp _largeStyles = RegExp(
    'display|headline',
    caseSensitive: false,
  );

  /// What the name of a disabled control's color contains: WCAG exempts
  /// inactive controls from contrast.
  static final RegExp _disabled = RegExp('disabled', caseSensitive: false);

  /// What a text style's name contains, such as `textTheme.bodySmall` or
  /// `AppTextStyle.caption`, to tell its `copyWith` from another's.
  static final RegExp _textStyles = RegExp(
    'style|textTheme',
    caseSensitive: false,
  );

  final _SourceFile _file;

  final List<ColorContrastCheck> _checks = [];

  /// How many colors could not be judged.
  int _unjudged = 0;

  final _ProjectTheme _theme;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _visitCall(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _visitCall(node);
    super.visitMethodInvocation(node);
  }

  /// Judges the [foreground] color [owner] gives to an [element] against
  /// what it is drawn on in each theme, counting it as not judged when
  /// either can't be read.
  ///
  /// With nothing painted around it, the surface is only assumed: a color
  /// failing there counts only for what the theme or an opacity causes, a
  /// color unreadable in the dark theme alone or one an opacity fades; any
  /// other may be drawn on a fill it gets elsewhere, so it is not judged.
  void _check(
    Expression foreground,
    _Call owner,
    ColorContrastElement element,
  ) {
    if (_file.isIgnoredAt(foreground) ||
        _disabled.hasMatch(foreground.toSource())) {
      return;
    }
    final samples = <_Sample>[];
    for (final isDark in _theme.scopeOf(owner.node) ?? _theme.brightnesses) {
      final color = _theme.colors.color(foreground, isDark: isDark);
      final backdrop = color == null
          ? null
          : _Backdrop.of(owner, _theme, isDark);
      if (color == null || backdrop == null) {
        _unjudged++;
        return;
      }
      samples.add((color: color, backdrop: backdrop, isDark: isDark));
    }
    final minimum = element.minimum;
    double ratio(_Sample sample) =>
        _drawn(sample).contrastWith(sample.backdrop.color);
    final failing = [
      for (final sample in samples)
        if (ratio(sample) < minimum) sample,
    ];
    // The theme judged is the one the colors fare worst in
    final worst = samples.reduce((a, b) => ratio(a) <= ratio(b) ? a : b);
    final isFaded =
        !worst.color.isOpaque &&
        worst.color.opaque.contrastWith(worst.backdrop.color) >= minimum;
    final isOneTheme = failing.length < samples.length;
    final failure = switch (failing) {
      [] => null,
      _ when isFaded => ColorContrastKind.translucent,
      _ when isOneTheme => ColorContrastKind.oneTheme,
      _ => ColorContrastKind.lowContrast,
    };
    if (failure != null &&
        worst.backdrop.isAssumed &&
        !isFaded &&
        !(isOneTheme && worst.isDark)) {
      _unjudged++;
      return;
    }
    final varies =
        {for (final sample in samples) (sample.color, sample.backdrop.color)}
            .length >
        1;
    final namesTheme =
        varies ||
        failure == ColorContrastKind.oneTheme ||
        (samples.length == 1 && worst.isDark);
    _checks.add(
      ColorContrastCheck(
        element: element,
        failure: failure,
        path: _file.path,
        line: _file.lineOf(foreground),
        foreground: ColorContrastAnalyzer._shown(foreground),
        foregroundColor: _drawn(worst),
        background: worst.backdrop.label,
        backgroundColor: worst.backdrop.color,
        theme: namesTheme ? _ProjectTheme.themeName(worst.isDark) : null,
      ),
    );
  }

  /// Whether the text style [call] builds is large text, by its size and
  /// weight, else by the name of the text theme style it copies.
  bool _isLarge(_Call call) {
    final size = switch (call['fontSize']) {
      final value? => _theme.colors.number(value),
      null => null,
    };
    if (size == null) {
      return _largeStyles.hasMatch(call.target?.toSource() ?? '');
    }
    final isBold = _boldWeights.contains(call['fontWeight']?.toSource());
    return size >= (isBold ? _largeBoldPoints : _largePoints) * _pixelsPerPoint;
  }

  /// Checks the colors [node] gives: a text style's, an icon's, or a
  /// widget's text and icon colors.
  void _visitCall(Expression node) {
    final call = _Call.of(node);
    if (call == null) return;
    final copiesTextStyle =
        call.member == 'copyWith' &&
        _textStyles.hasMatch(call.target?.toSource() ?? '');
    if (call.fullName == 'TextStyle' || copiesTextStyle) {
      if (call['color'] case final color?) {
        _check(
          color,
          call,
          _isLarge(call)
              ? ColorContrastElement.largeText
              : ColorContrastElement.text,
        );
      }
      return;
    }
    if (!call.isClass) return;
    if (call['color'] case final color? when _icons.contains(call.typeName)) {
      _check(color, call, ColorContrastElement.icon);
    }
    for (final (name, value) in call.named) {
      if (_textColors.contains(name)) {
        _check(
          value,
          call,
          _iconWidgets.contains(call.typeName)
              ? ColorContrastElement.icon
              : ColorContrastElement.text,
        );
      } else if (name == _iconColor) {
        _check(value, call, ColorContrastElement.icon);
      }
    }
  }

  /// The foreground of [sample] as drawn: a translucent one mixed with
  /// its backdrop.
  static WcagColor _drawn(_Sample sample) => sample.color.isOpaque
      ? sample.color
      : sample.color.over(sample.backdrop.color);

  /// The texts and icons of [file] judged in [theme], and how many could
  /// not be judged.
  static ({List<ColorContrastCheck> checks, int unjudged}) judge(
    _SourceFile file,
    _ProjectTheme theme,
  ) {
    if (file.isIgnored) return (checks: const [], unjudged: 0);
    final visitor = _ContrastVisitor(file, theme);
    file.unit.accept(visitor);
    return (checks: visitor._checks, unjudged: visitor._unjudged);
  }
}
