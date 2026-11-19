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
    this.schemes,
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
    // Where a node is: the file whose code it is part of
    final fileOf = {for (final file in files) file.unit: file};
    final definitions = [
      for (final (expression, file) in collector.schemes)
        for (final scheme in _SchemeDefinition.readAll(expression, defaults))
          (scheme, file, expression),
    ];
    // The schemes the themes use, each with the file and node defining
    // it, the first ones of a theme winning, then any the code builds; a
    // theme's scheme that can't be read is kept to tell where it is
    final themeSchemes = [
      for (final (theme, file) in collector.themes)
        if (theme['colorScheme'] ??
                (theme['colorSchemeSeed'] == null ? null : theme.node)
            case final Expression scheme)
          (scheme, fileOf[defaults.resolve(scheme).root] ?? file),
    ];
    final sources = <(_SchemeDefinition, _SourceFile, AstNode)>[
      for (final (scheme, file) in themeSchemes)
        for (final definition in _SchemeDefinition.readAll(scheme, defaults))
          (definition, file, defaults.resolve(scheme)),
      ...definitions,
    ];
    final unread = [
      for (final (scheme, file) in themeSchemes)
        if (_SchemeDefinition.readAll(scheme, defaults).isEmpty)
          (file, defaults.resolve(scheme)),
    ];
    (_SchemeDefinition, _SourceFile, AstNode)? sourceOf(bool isDark) {
      for (final source in sources) {
        if (source.$1.roles.isDark == isDark) return source;
      }
      return null;
    }

    ColorRoles schemeOf(bool isDark) =>
        sourceOf(isDark)?.$1.roles ?? ColorRoles.material3(isDark: isDark);

    final hints = {
      for (final (theme, _) in collector.themes)
        ..._brightnessesOf(theme, defaults),
      for (final (definition, _, _) in definitions) definition.roles.isDark,
    };
    // The fills each theme gives widgets, the first theme of a brightness
    // that gives one winning
    final themedFills = <bool, Map<String, _Fill>>{false: {}, true: {}};
    for (final (theme, _) in collector.themes) {
      for (final MapEntry(key: slot, value: widget) in _themeSlots.entries) {
        if (theme[slot] case final value?) {
          final fill = widget == 'Scaffold'
              ? _Fill.color(value)
              : switch (_Call.of(defaults.resolve(value))) {
                  final component? => _Fill.of(component, defaults),
                  null => _Fill.unknown,
                };
          if (fill.kind case _FillKind.color || _FillKind.unknown) {
            for (final isDark in _brightnessesOf(theme, defaults)) {
              themedFills[isDark]!.putIfAbsent(widget, () => fill);
            }
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
    final brightnesses = switch (onlyDark) {
      final isDark? => [isDark],
      null when collector.hasDarkTheme || hints.length > 1 => const [
        false,
        true,
      ],
      null => [hints.contains(true)],
    };
    return _ProjectTheme._(
      _ColorEvaluator(
        collector.constants,
        light: schemeOf(false),
        dark: schemeOf(true),
      ),
      brightnesses,
      definitions,
      themedFills,
      {
        for (final MapEntry(key: name, value: declaration)
            in collector.classes.entries)
          if (_paints(declaration, defaults)) name,
      },
      [
        for (final isDark in brightnesses)
          switch (sourceOf(isDark)) {
            (final definition, final file, final node) => ColorSchemeSummary(
              theme: themeName(isDark),
              roles: definition.roles,
              origin: definition.origin,
              givenRoles: definition.given.keys.toList(),
              path: file.path,
              line: file.lineOf(node),
            ),
            null => switch (unread) {
              [(final file, final node), ...] => ColorSchemeSummary(
                theme: themeName(isDark),
                roles: ColorRoles.material3(isDark: isDark),
                origin: "Can't be read here: Material 3's default is assumed",
                path: file.path,
                line: file.lineOf(node),
              ),
              [] => ColorSchemeSummary(
                theme: themeName(isDark),
                roles: ColorRoles.material3(isDark: isDark),
                origin: "Material 3's default",
              ),
            },
          },
      ],
    );
  }

  /// The themes the app renders: false for the light one, true for the
  /// dark one.
  final List<bool> brightnesses;

  /// Reads colors with the app's color schemes and the project's
  /// constants.
  final _ColorEvaluator colors;

  /// The color scheme of each theme the app renders, as [brightnesses]
  /// order them.
  final List<ColorSchemeSummary> schemes;

  /// The color schemes the code defines, each with its file and node.
  final List<(_SchemeDefinition, _SourceFile, AstNode)> _definitions;

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

  /// Each on-color of the schemes the code defines judged on its fill.
  List<ColorContrastCheck> pairChecks() => [
    for (final (definition, file, _) in _definitions)
      ...definition.pairChecks(file),
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
        return _brightnessesOf(call, colors);
      }
    }
    return null;
  }

  /// The name of the dark theme when [isDark], else the light one's.
  static String themeName(bool isDark) => isDark ? 'dark' : 'light';

  /// Whether the code of the class [declaration] paints a fill, reading
  /// constants with [colors].
  static bool _paints(ClassDeclaration declaration, _ColorEvaluator colors) {
    final finder = _PaintFinder(colors);
    declaration.accept(finder);
    return finder.paints;
  }

  /// The themes the `ThemeData` [call] builds, false for the light one,
  /// reading its scheme with [colors]: both when its brightness is not a
  /// constant, such as a parameter of a function building both.
  static List<bool> _brightnessesOf(_Call call, _ColorEvaluator colors) {
    switch (call.member) {
      case 'dark':
        return const [true];
      case 'light':
        return const [false];
    }
    if (call['brightness'] case final brightness?) {
      return switch (_SchemeDefinition.darkBrightness(brightness)) {
        final isDark? => [isDark],
        null => const [false, true],
      };
    }
    final scheme = call['colorScheme'];
    final schemes = scheme == null
        ? const <_SchemeDefinition>[]
        : _SchemeDefinition.readAll(scheme, colors);
    return schemes.isEmpty
        ? const [false]
        : [for (final scheme in schemes) scheme.roles.isDark];
  }
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
