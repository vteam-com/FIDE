part of 'color_contrast_analyzer.dart';

/// The project's colors as its app renders them: the themes it renders,
/// the color scheme of each, its constants, and the color schemes its
/// code defines.
class _ProjectTheme {
  _ProjectTheme._(
    this.colors,
    this.brightnesses,
    this._definitions,
    this._themedFills,
    this._paintingClasses,
  );

  /// The arguments of `ThemeData` that set the fill of a widget, with the
  /// widget.
  static const Map<String, String> _themeSlots = {
    'appBarTheme': 'AppBar',
    'badgeTheme': 'Badge',
    'bottomSheetTheme': 'BottomSheet',
    'cardTheme': 'Card',
    'chipTheme': 'Chip',
    'dialogTheme': 'Dialog',
    'drawerTheme': 'Drawer',
    'elevatedButtonTheme': 'ElevatedButton',
    'filledButtonTheme': 'FilledButton',
    'floatingActionButtonTheme': 'FloatingActionButton',
    'navigationBarTheme': 'NavigationBar',
    'outlinedButtonTheme': 'OutlinedButton',
    'scaffoldBackgroundColor': 'Scaffold',
    'snackBarTheme': 'SnackBar',
    'textButtonTheme': 'TextButton',
  };

  /// Widgets styled by another's component theme, such as an `AlertDialog`
  /// by the `dialogTheme`.
  static const Map<String, String> _themedAs = {
    'AlertDialog': 'Dialog',
    'SimpleDialog': 'Dialog',
    'SliverAppBar': 'AppBar',
  };

  /// Reads what [files] declare about their colors and themes.
  factory _ProjectTheme.collect(List<_SourceFile> files) {
    final collector = _DeclarationCollector();
    for (final file in files) {
      collector.collect(file);
    }
    // Schemes are read with Material's default roles: a scheme built
    // from another scheme's roles is rare
    final defaults = _ColorEvaluator(
      collector.constants,
      light: ColorRoles.material3(isDark: false),
      dark: ColorRoles.material3(isDark: true),
    );
    final definitions = [
      for (final (expression, file) in collector.schemes)
        if (_SchemeDefinition.read(expression, defaults) case final scheme?)
          (scheme, file),
    ];
    // The schemes the themes use first, then any the code builds
    final schemes = [
      for (final theme in collector.themes)
        if (theme['colorScheme'] ??
                (theme['colorSchemeSeed'] == null ? null : theme.node)
            case final Expression scheme)
          ?_SchemeDefinition.read(scheme, defaults)?.roles,
      for (final (definition, _) in definitions) definition.roles,
    ];
    ColorRoles schemeOf(bool isDark) {
      for (final scheme in schemes) {
        if (scheme.isDark == isDark) return scheme;
      }
      return ColorRoles.material3(isDark: isDark);
    }

    final hints = {
      for (final theme in collector.themes) _isDarkTheme(theme, defaults),
      for (final (definition, _) in definitions) definition.roles.isDark,
    };
    // The fills each theme gives widgets, the first theme of a brightness
    // that gives one winning
    final themedFills = <bool, Map<String, _Fill>>{false: {}, true: {}};
    for (final theme in collector.themes) {
      final fills = themedFills[_isDarkTheme(theme, defaults)]!;
      for (final MapEntry(key: slot, value: widget) in _themeSlots.entries) {
        if (theme[slot] case final value?) {
          final fill = widget == 'Scaffold'
              ? _Fill.color(value)
              : switch (_Call.of(defaults.resolve(value))) {
                  final component? => _Fill.of(component, defaults),
                  null => _Fill.unknown,
                };
          if (fill.kind case _FillKind.color || _FillKind.unknown) {
            fills.putIfAbsent(widget, () => fill);
          }
        }
      }
    }
    // An app set to one theme, not one picked at run time, renders only it
    final bool? onlyDark = switch (collector.themeModes) {
      final modes when modes.length == 1 => switch (modes.single) {
        'ThemeMode.dark' => true,
        'ThemeMode.light' => false,
        _ => null,
      },
      _ => null,
    };
    return _ProjectTheme._(
      _ColorEvaluator(
        collector.constants,
        light: schemeOf(false),
        dark: schemeOf(true),
      ),
      switch (onlyDark) {
        final isDark? => [isDark],
        null when collector.hasDarkTheme || hints.length > 1 => const [
          false,
          true,
        ],
        null => [hints.contains(true)],
      },
      definitions,
      themedFills,
      {
        for (final MapEntry(key: name, value: declaration)
            in collector.classes.entries)
          if (_paints(declaration, defaults)) name,
      },
    );
  }

  /// The themes the app renders: false for the light one, true for the
  /// dark one.
  final List<bool> brightnesses;

  /// Reads colors with the app's color schemes and the project's
  /// constants.
  final _ColorEvaluator colors;

  /// The color schemes the code defines, each with its file.
  final List<(_SchemeDefinition, _SourceFile)> _definitions;

  /// The fill each theme gives widgets in place of their default, by
  /// brightness then widget.
  final Map<bool, Map<String, _Fill>> _themedFills;

  /// The project's widgets whose code paints a fill: what is given them
  /// to show may be drawn on it, so it is not judged.
  final Set<String> _paintingClasses;

  /// What [call] paints behind its content in the dark theme when
  /// [isDark], else the light one: the color its code gives, else the one
  /// the theme gives its kind of widget, else its default.
  _Fill fillOf(_Call call, bool isDark) {
    final fill = _Fill.of(call, colors);
    if (fill.kind case _FillKind.color || _FillKind.unknown) return fill;
    if (_paintingClasses.contains(call.typeName)) return _Fill.unknown;
    final widget = _Fill.widgetOf(call);
    return _themedFills[isDark]![_themedAs[widget] ?? widget] ?? fill;
  }

  /// The on-colors of the schemes the code defines that fall below WCAG 2
  /// level AA on their fill.
  List<ColorContrastFinding> pairFindings() => [
    for (final (definition, file) in _definitions)
      ...definition.pairFindings(file),
  ];

  /// The scheme of the dark theme when [isDark], else the light one's.
  ColorRoles schemeOf(bool isDark) => colors.schemeOf(isDark);

  /// The one theme [node] is drawn in when it is part of a `ThemeData`,
  /// such as a text style of the dark theme; null when it is drawn in
  /// every theme the app renders.
  List<bool>? scopeOf(AstNode node) {
    for (AstNode? current = node; current != null; current = current.parent) {
      if (_Call.of(current) case final call?
          when call.typeName == 'ThemeData') {
        return [_isDarkTheme(call, colors)];
      }
    }
    return null;
  }

  /// Whether the code of the class [declaration] paints a fill, reading
  /// constants with [colors].
  static bool _paints(ClassDeclaration declaration, _ColorEvaluator colors) {
    final finder = _PaintFinder(colors);
    declaration.accept(finder);
    return finder.paints;
  }

  /// Whether the `ThemeData` [call] builds a dark theme, reading its
  /// scheme with [colors].
  static bool _isDarkTheme(_Call call, _ColorEvaluator colors) =>
      switch (call.member) {
        'dark' => true,
        'light' => false,
        _ when call['brightness'] != null => _SchemeDefinition.isDarkBrightness(
          call['brightness'],
        ),
        _ => switch (call['colorScheme']) {
          final scheme? =>
            _SchemeDefinition.read(scheme, colors)?.roles.isDark ?? false,
          null => false,
        },
      };
}

/// Tells whether code paints a fill: whether a call in it does, as a
/// `Container` with a color or a `Card` does.
class _PaintFinder extends RecursiveAstVisitor<void> {
  _PaintFinder(this._colors);

  /// Whether a call painting a fill was found.
  bool paints = false;

  /// Reads the constants a decoration or a style names.
  final _ColorEvaluator _colors;

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

  /// Notes whether [node] paints a fill.
  void _visitCall(Expression node) {
    if (paints) return;
    final call = _Call.of(node);
    paints = call != null && _Fill.of(call, _colors).kind != _FillKind.none;
  }
}
