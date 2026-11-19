part of 'color_contrast_analyzer.dart';

/// What a widget paints behind its content.
enum _FillKind {
  /// Nothing: its content shows what is behind the widget.
  none,

  /// Something that can't be read, such as a gradient or a themed default
  /// not known here: its content is not judged.
  unknown,

  /// A color the code gives.
  color,

  /// A role of the color scheme, the widget's Material 3 default.
  role,
}

/// What a widget paints behind its content, for the text and icons in it:
/// nothing, a color the code gives, the widget's Material 3 default, or
/// something that can't be read.
class _Fill {
  const _Fill._(this.kind) : expression = null, role = null, widget = null;

  /// The fill of the color [expression] stands for.
  const _Fill.color(Expression this.expression)
    : kind = _FillKind.color,
      role = null,
      widget = null;

  /// The fill of [widget]'s default: the scheme's [role].
  const _Fill.role(String this.role, String this.widget)
    : kind = _FillKind.role,
      expression = null;

  /// No fill: the content shows what is behind.
  static const _Fill none = _Fill._(_FillKind.none);

  /// A fill that can't be read.
  static const _Fill unknown = _Fill._(_FillKind.unknown);

  /// Widgets whose `color` is the fill behind their content.
  static const Set<String> _colorFills = {
    'AnimatedContainer',
    'Card',
    'ColoredBox',
    'Container',
    'Ink',
    'Material',
  };

  /// The role of the color scheme Material 3 fills each widget with when
  /// the code gives none, by widget or named constructor; checked against
  /// the Flutter SDK's `*DefaultsM3` classes.
  static const Map<String, String> _defaultFills = {
    'AlertDialog': 'surfaceContainerHigh',
    'AppBar': 'surface',
    'Badge': 'error',
    'BottomSheet': 'surfaceContainerLow',
    'Card': 'surfaceContainerLow',
    'Dialog': 'surfaceContainerHigh',
    'Drawer': 'surfaceContainerLow',
    'ElevatedButton': 'surfaceContainerLow',
    'FilledButton': 'primary',
    'FilledButton.tonal': 'secondaryContainer',
    'FilledButton.tonalIcon': 'secondaryContainer',
    'FloatingActionButton': 'primaryContainer',
    'NavigationBar': 'surfaceContainer',
    'Scaffold': 'surface',
    'SimpleDialog': 'surfaceContainerHigh',
    'SliverAppBar': 'surface',
    'SnackBar': 'inverseSurface',
  };

  /// Widgets that fill their content with a themed default not known
  /// here: what is in them is not judged without a color the code gives.
  static const Set<String> _themedFills = {
    'ActionChip',
    'BottomAppBar',
    'BottomNavigationBar',
    'Chip',
    'ChoiceChip',
    'CircleAvatar',
    'DropdownMenu',
    'FilterChip',
    'InputChip',
    'Material',
    'MaterialBanner',
    'NavigationDrawer',
    'NavigationRail',
    'PopupMenuButton',
    'RawChip',
    'SearchBar',
    'SegmentedButton',
    'ToggleButtons',
    'Tooltip',
  };

  /// Text fields, whose `decoration` is an input decoration, not a fill.
  static const Set<String> _inputs = {
    'DropdownButtonFormField',
    'InputDecorator',
    'TextField',
    'TextFormField',
  };

  /// The decoration of a text field, filled with `fillColor` when
  /// `filled`.
  static const String _inputDecoration = 'InputDecoration';

  /// Decorations whose `color` fills the box they decorate.
  static const Set<String> _decorations = {'BoxDecoration', 'ShapeDecoration'};

  /// Ends of the names of component themes, such as `AppBarTheme`, which
  /// set what their widget fills.
  static const List<String> _themeSuffixes = ['ThemeData', 'Theme'];

  /// The widget whose content is drawn on the fill.
  final String? widget;

  /// The color the code gives, for [_FillKind.color].
  final Expression? expression;

  /// What the fill is.
  final _FillKind kind;

  /// The scheme role, for [_FillKind.role].
  final String? role;

  /// What [call] paints behind its content, following the constants
  /// [colors] knows to read a decoration or a style.
  static _Fill of(_Call call, _ColorEvaluator colors) {
    if (call.member == 'styleFrom') return _styleFrom(call);
    if (!call.isClass) {
      // A text style's copy can give its own background
      return switch (call['backgroundColor']) {
        final color? when call.member == 'copyWith' => _Fill.color(color),
        _ => none,
      };
    }
    final name = call.typeName;
    // A theme of its own, or Cupertino's adaptive colors
    if (name == 'Theme' || name.startsWith('Cupertino')) return unknown;
    if (name == _inputDecoration) return _input(call);
    final widget = _widgetOf(name);
    final color =
        call['backgroundColor'] ??
        call['tileColor'] ??
        (_colorFills.contains(widget) ? call['color'] : null);
    if (color != null) return _Fill.color(color);
    if (call['decoration'] case final decoration?) {
      final resolved = colors.resolve(decoration);
      final fill = _inputs.contains(name)
          ? _textFieldFill(resolved)
          : _decoration(resolved);
      if (fill.kind != _FillKind.none) return fill;
    }
    if (call['style'] case final style? when widget.endsWith('Button')) {
      return _buttonStyle(colors.resolve(style), call.fullName);
    }
    return _defaultOf(call.fullName);
  }

  /// The widget whose default fill [call] paints, or whose component
  /// theme it is: `AppBar` for `AppBarTheme(…)`, `ElevatedButton` for
  /// `ElevatedButton.styleFrom(…)`.
  static String widgetOf(_Call call) =>
      call.member == 'styleFrom' ? call.typeName : _widgetOf(call.typeName);

  /// The fill of a button of [button] styled by [style]: its background
  /// when the style gives one, else the button's default.
  static _Fill _buttonStyle(Expression style, String button) {
    final call = _Call.of(style);
    if (call?.member == 'styleFrom') return _styleFrom(call!);
    if (call?.typeName != 'ButtonStyle') return unknown;
    return switch (call!['backgroundColor']) {
      final color? => _Fill.color(color),
      null => _defaultOf(button),
    };
  }

  /// The fill of a text field: the `fillColor` of its input decoration
  /// [call] when `filled`, nothing otherwise.
  static _Fill _input(_Call call) {
    if (call['filled']?.toSource() != 'true') return none;
    return switch (call['fillColor']) {
      final color? => _Fill.color(color),
      null => unknown,
    };
  }

  /// The fill of a text field decorated with [decoration].
  static _Fill _textFieldFill(Expression decoration) {
    final call = _Call.of(decoration);
    return call?.typeName == _inputDecoration ? _input(call!) : unknown;
  }

  /// The fill of a box decorated with [decoration].
  static _Fill _decoration(Expression decoration) {
    final call = _Call.of(decoration);
    if (call == null || !_decorations.contains(call.typeName)) return unknown;
    if (call['color'] case final color?) return _Fill.color(color);
    return call['gradient'] != null || call['image'] != null ? unknown : none;
  }

  /// What the widget [fullName] (or the one its component theme styles)
  /// fills with when the code gives no color.
  static _Fill _defaultOf(String fullName) {
    final widget = _widgetOf(fullName.split('.').first);
    final role = _defaultFills[fullName] ?? _defaultFills[widget];
    if (role != null) return _Fill.role(role, widget);
    return _themedFills.contains(widget) ? unknown : none;
  }

  /// The fill of a button styled by the `styleFrom` [call]: its
  /// background, else the default of the button whose `styleFrom` it is.
  static _Fill _styleFrom(_Call call) => switch (call['backgroundColor']) {
    final color? => _Fill.color(color),
    null => _defaultOf(call.typeName),
  };

  /// The widget [name] styles: `AppBar` for `AppBarTheme`, itself for a
  /// widget.
  static String _widgetOf(String name) {
    for (final suffix in _themeSuffixes) {
      if (name.length > suffix.length && name.endsWith(suffix)) {
        return name.substring(0, name.length - suffix.length);
      }
    }
    return name;
  }
}
