part of 'color_contrast_analyzer.dart';

/// Reads the color an expression of unresolved code stands for, in the
/// light or the dark theme: a `Color` literal, Material's `Colors`, the
/// project's constants and locals, its color scheme's roles, and these
/// made translucent; null for anything else, which is never guessed.
class _ColorEvaluator {
  _ColorEvaluator(this._constants, {required this.light, required this.dark});

  /// Methods making a color translucent.
  static const String _withOpacity = 'withOpacity';

  static const String _withAlpha = 'withAlpha';

  static const String _withValues = 'withValues';

  /// The methods making a color translucent.
  static const Set<String> _modifiers = {_withOpacity, _withAlpha, _withValues};

  /// What starts the code of a constant instance creation.
  static const String _constPrefix = 'const ';

  /// Wrappers of one color for every state, as a `ButtonStyle` takes it.
  static const Set<String> _allStates = {
    'WidgetStatePropertyAll',
    'MaterialStatePropertyAll',
    'WidgetStateProperty.all',
    'MaterialStateProperty.all',
  };

  /// Swatch constructors, whose first argument is the primary value.
  static const Set<String> _swatches = {'MaterialColor', 'MaterialAccentColor'};

  /// `Colors.grey.shade600`'s member: a shade by its number.
  static final RegExp _shade = RegExp(r'^shade(\d+)$');

  /// Members of `ThemeData` that are the scheme's surface in Material 3.
  static const Set<String> _surfaceMembers = {
    'scaffoldBackgroundColor',
    'canvasColor',
  };

  /// The class name of Material's colors.
  static const String _colors = 'Colors';

  /// Name of a color scheme, as `Theme.of(context).colorScheme` ends.
  static const String _colorScheme = 'colorScheme';

  /// The scheme roles are read from in the dark theme.
  final ColorRoles dark;

  /// The scheme roles are read from in the light theme.
  final ColorRoles light;

  /// Initializers of the project's top-level and static constants, by name
  /// (`kBrand`) and by class and name (`AppColors.brand`).
  final Map<String, Expression> _constants;

  /// The color [expression] stands for in the dark theme when [isDark],
  /// else in the light one; null when it can't be read.
  WcagColor? color(Expression expression, {required bool isDark}) =>
      _color(expression, isDark, {});

  /// What the constant or local [expression] names is initialized with,
  /// followed through names of names; [expression] itself otherwise.
  Expression resolve(Expression expression) {
    var current = expression;
    final seen = <String>{};
    while (seen.add(current.toSource())) {
      final next = _initializerOf(current);
      if (next == null) break;
      current = next;
    }
    return current;
  }

  /// Whether [name] is the name of a top-level or static constant.
  bool isConstant(String name) => _constants.containsKey(name);

  /// How the color [expression] is written, alike wherever it is: a role
  /// of the color scheme as `colorScheme.primary` however the scheme is
  /// reached, without `const`, a trailing `!` or a state wrapper.
  String nameOf(Expression expression) {
    // The color a state wrapper gives every state
    if (_Call.of(expression) case final call?
        when _allStates.contains(call.fullName) && call.positional.isNotEmpty) {
      return nameOf(call.positional.first);
    }
    return _nameOf(expression);
  }

  /// [nameOf]'s work on anything but a state wrapper.
  String _nameOf(Expression expression) => switch (expression) {
    ParenthesizedExpression(:final expression) => nameOf(expression),
    PostfixExpression(:final operand)
        when expression.operator.type == TokenType.BANG =>
      nameOf(operand),
    PrefixedIdentifier(:final prefix, :final identifier)
        when ColorRoles.isRole(identifier.name) && _isScheme(prefix) =>
      '$_colorScheme.${identifier.name}',
    PropertyAccess(:final target?, :final propertyName)
        when ColorRoles.isRole(propertyName.name) && _isScheme(target) =>
      '$_colorScheme.${propertyName.name}',
    MethodInvocation(:final target?, :final methodName, :final argumentList) =>
      '${nameOf(target)}.${methodName.name}${argumentList.toSource()}',

    _ => switch (expression.toSource()) {
      final source when source.startsWith(_constPrefix) => source.substring(
        _constPrefix.length,
      ),
      final source => source,
    },
  };

  /// The scheme of the dark theme when [isDark], else the light one's.
  ColorRoles schemeOf(bool isDark) => isDark ? dark : light;

  /// [expression]'s value as a number; null when it isn't a literal or a
  /// constant one.
  double? number(Expression expression) => switch (resolve(expression)) {
    IntegerLiteral(:final value?) => value.toDouble(),
    DoubleLiteral(:final value) => value,
    PrefixExpression(:final operator, :final operand)
        when operator.type == TokenType.MINUS =>
      switch (number(operand)) {
        final value? => -value,
        null => null,
      },
    _ => null,
  };

  /// [_color]'s work on a call: a `Color` constructor, a swatch, a color
  /// made translucent, or a state wrapper.
  WcagColor? _call(_Call call, bool isDark, Set<String> visiting) {
    final positional = call.positional;
    double? named(String name) => switch (call[name]) {
      final value? => number(value),
      null => null,
    };
    double? first() => positional.isEmpty ? null : number(positional.first);
    if (call.target case final target?) {
      // Any other method is not read, nor its value: most calls of the
      // code are not colors
      if (!_modifiers.contains(call.member)) return null;
      final base = _color(target, isDark, visiting);
      if (base == null) return null;
      final amount = first();
      // Only an alpha: a changed channel or color space is not read
      final alpha = call.named.length == 1 ? named('alpha') : null;
      return switch (call.member) {
        _withOpacity when amount != null => base.withOpacity(amount),
        _withAlpha when amount != null => base.withAlpha(amount.toInt()),
        _withValues when alpha != null => base.withOpacity(alpha),
        _ => null,
      };
    }
    if (_allStates.contains(call.fullName)) {
      return positional.isEmpty
          ? null
          : _color(positional.first, isDark, visiting);
    }
    if (_swatches.contains(call.typeName) || call.fullName == 'Color') {
      final argb = first();
      return argb == null ? null : WcagColor(argb.toInt());
    }
    if (call.typeName != 'Color') return null;
    final numbers = [for (final argument in positional) number(argument)];
    int byte(double value) => (value * WcagColor.channelMax).round();
    return switch ((call.member, numbers)) {
      ('fromARGB', [final a?, final r?, final g?, final b?]) =>
        WcagColor.fromChannels(a.toInt(), r.toInt(), g.toInt(), b.toInt()),
      // The opacity truncated, as Flutter's Color.fromRGBO does
      ('fromRGBO', [final r?, final g?, final b?, final opacity?]) =>
        WcagColor.fromChannels(
          (opacity * WcagColor.channelMax).toInt(),
          r.toInt(),
          g.toInt(),
          b.toInt(),
        ),
      ('from', _) => switch ([
        for (final name in ['alpha', 'red', 'green', 'blue']) named(name),
      ]) {
        [final a?, final r?, final g?, final b?] => WcagColor.fromChannels(
          byte(a),
          byte(r),
          byte(g),
          byte(b),
        ),
        _ => null,
      },
      _ => null,
    };
  }

  /// The color [expression] stands for, [visiting] the names already
  /// being followed, so a constant defined by itself ends.
  WcagColor? _color(Expression expression, bool isDark, Set<String> visiting) {
    switch (expression) {
      case ParenthesizedExpression(:final expression):
        return _color(expression, isDark, visiting);
      case PostfixExpression(:final operand)
          when expression.operator.type == TokenType.BANG:
        return _color(operand, isDark, visiting);
      // Colors.grey[600]
      case IndexExpression(:final target?, :final index):
        final shade = number(index)?.toInt();
        return shade == null ? null : _shadeOf(target, shade);
      case PrefixedIdentifier(:final prefix, :final identifier):
        return _member(prefix, identifier.name, isDark) ??
            _named(expression, isDark, visiting);
      case PropertyAccess(:final target?, :final propertyName):
        return _member(target, propertyName.name, isDark);
      case SimpleIdentifier():
        return _named(expression, isDark, visiting);
      case MethodInvocation() || InstanceCreationExpression():
        final call = _Call.of(expression);
        return call == null ? null : _call(call, isDark, visiting);
      default:
        return null;
    }
  }

  /// The initializer of the constant or the earlier local [expression]
  /// names; null when it names neither.
  Expression? _initializerOf(Expression expression) => switch (expression) {
    SimpleIdentifier(:final name) =>
      _localInitializer(expression) ?? _constants[name],
    PrefixedIdentifier(:final prefix, :final identifier) =>
      _constants['${prefix.name}.${identifier.name}'],
    _ => null,
  };

  /// Whether [target] is a color scheme: `Theme.of(context).colorScheme`,
  /// `theme.colorScheme`, or a local holding one.
  bool _isScheme(Expression target) {
    final source = target.toSource();
    if (source == _colorScheme || source.endsWith('.$_colorScheme')) {
      return true;
    }
    final initializer = target is SimpleIdentifier
        ? _localInitializer(target)
        : null;
    return initializer != null && _isScheme(initializer);
  }

  /// What the local variable [name] was declared with before it is read;
  /// null when it isn't a local, or isn't initialized.
  Expression? _localInitializer(SimpleIdentifier name) {
    AstNode child = name;
    for (var node = name.parent; node != null; node = node.parent) {
      if (node is Block) {
        for (final statement in node.statements) {
          if (identical(statement, child)) break;
          if (statement is VariableDeclarationStatement) {
            for (final variable in statement.variables.variables) {
              if (variable.name.lexeme == name.name) {
                return variable.initializer;
              }
            }
          }
        }
      }
      if (node is ClassDeclaration || node is CompilationUnit) return null;
      child = node;
    }
    return null;
  }

  /// [target]'s member [name]: one of Material's colors or a shade of one,
  /// a role of a color scheme, or a surface of the theme; null otherwise.
  WcagColor? _member(Expression target, String name, bool isDark) {
    final source = target.toSource();
    if (source == _colors) {
      return switch (MaterialPalette.colors[name]) {
        final argb? => WcagColor(argb),
        null => null,
      };
    }
    if (_shade.firstMatch(name) case final match?) {
      return _shadeOf(target, int.parse(match.group(1)!));
    }
    if (ColorRoles.isRole(name) && _isScheme(target)) {
      return schemeOf(isDark)[name];
    }
    if (_surfaceMembers.contains(name) &&
        source.endsWith('Theme.of(context)')) {
      return schemeOf(isDark)['surface'];
    }
    return null;
  }

  /// The color the constant or local [expression] names; null when it
  /// names neither, or one being followed already.
  WcagColor? _named(Expression expression, bool isDark, Set<String> visiting) {
    final source = expression.toSource();
    final initializer = _initializerOf(expression);
    if (initializer == null || !visiting.add(source)) return null;
    final color = _color(initializer, isDark, visiting);
    visiting.remove(source);
    return color;
  }

  /// Shade [shade] of the swatch [swatch] names, such as `Colors.grey`;
  /// null when it isn't one of Material's.
  WcagColor? _shadeOf(Expression swatch, int shade) {
    final name = switch (swatch) {
      PrefixedIdentifier(:final prefix, :final identifier)
          when prefix.name == _colors =>
        identifier.name,
      _ => null,
    };
    return switch (MaterialPalette.shades[name]?[shade]) {
      final argb? => WcagColor(argb),
      null => null,
    };
  }
}
