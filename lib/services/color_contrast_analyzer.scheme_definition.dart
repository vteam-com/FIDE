part of 'color_contrast_analyzer.dart';

/// A color scheme the project's code builds: its colors, the roles the
/// code gives with their values, and the given roles that can't be read.
class _SchemeDefinition {
  _SchemeDefinition(this.roles, this.given, this.unread);

  /// The roles the code gives, each with the value it gives.
  final Map<String, Expression> given;

  /// The scheme's colors.
  final ColorRoles roles;

  /// Given roles whose value can't be read, whose pairs are not judged.
  final Set<String> unread;

  /// The on-colors of the scheme that fall below WCAG 2 level AA on their
  /// fill, where the code gives one of the two, in [file].
  List<ColorContrastFinding> pairFindings(_SourceFile file) => [
    for (final (fill, on) in ColorRoles.pairs)
      if ((given[on] ?? given[fill]) case final value?
          when !unread.contains(fill) &&
              !unread.contains(on) &&
              !file.isIgnoredAt(value))
        if ((roles[fill]?.opaque, roles[on]) case (
          final fillColor?,
          final onColor?,
        ))
          if (onColor.isOpaque ? onColor : onColor.over(fillColor)
              case final drawn
              when drawn.contrastWith(fillColor) < WcagColor.minTextContrast)
            ColorContrastFinding(
              kind: ColorContrastKind.themePair,
              path: file.path,
              line: file.lineOf(value),
              foreground: on,
              foregroundColor: drawn,
              background: fill,
              backgroundColor: fillColor,
              minimum: WcagColor.minTextContrast,
              theme: roles.isDark ? 'dark' : 'light',
            ),
  ];

  /// Whether a theme or scheme's `brightness` [value] is dark.
  static bool isDarkBrightness(Expression? value) =>
      value?.toSource().endsWith('.dark') ?? false;

  /// The scheme [expression] builds, reading its colors with [colors]:
  /// `ColorScheme(…)`, `ColorScheme.light/dark(…)`,
  /// `ColorScheme.fromSeed(…)`, `ThemeData(colorSchemeSeed: …)`, a copy of
  /// one, or a constant holding one; null for anything else, or a seed
  /// that can't be read.
  static _SchemeDefinition? read(
    Expression expression,
    _ColorEvaluator colors,
  ) {
    final call = _Call.of(colors.resolve(expression));
    if (call == null) return null;
    if ((call.member, call.target) case ('copyWith', final target?)) {
      final base = read(target, colors);
      if (base == null) return null;
      final (given, unread) = _rolesOf(call, colors, base.roles.isDark);
      return _SchemeDefinition(
        base.roles.copyWith(given),
        {...base.given, ..._valuesOf(call)},
        {...base.unread, ...unread},
      );
    }
    final isDark = switch (call.fullName) {
      'ColorScheme.dark' => true,
      'ColorScheme.light' => false,
      _ => isDarkBrightness(call['brightness']),
    };
    final (given, unread) = _rolesOf(call, colors, isDark);
    final roles = switch (call.fullName) {
      'ColorScheme' => ColorRoles.complete(given, isDark: isDark),
      'ColorScheme.light' ||
      'ColorScheme.dark' => ColorRoles.legacy(given, isDark: isDark),
      'ColorScheme.fromSeed' => _fromSeed(
        call,
        call['seedColor'],
        colors,
        isDark: isDark,
        given: given,
      ),
      'ThemeData' => _fromSeed(
        call,
        call['colorSchemeSeed'],
        colors,
        isDark: isDark,
      ),
      _ => null,
    };
    return roles == null
        ? null
        : _SchemeDefinition(roles, _valuesOf(call), unread);
  }

  /// The scheme generated from the seed [seed] as [call] asks, its variant
  /// and contrast level included; null when the seed can't be read.
  static ColorRoles? _fromSeed(
    _Call call,
    Expression? seed,
    _ColorEvaluator colors, {
    required bool isDark,
    Map<String, WcagColor> given = const {},
  }) {
    final color = seed == null ? null : colors.color(seed, isDark: isDark);
    if (color == null) return null;
    final contrast = call['contrastLevel'];
    return ColorRoles.fromSeed(
      color,
      isDark: isDark,
      variant:
          call['dynamicSchemeVariant']?.toSource().split('.').last ??
          ColorRoles.tonalSpot,
      contrastLevel: (contrast == null ? null : colors.number(contrast)) ?? 0,
      given: given,
    );
  }

  /// The colors of the roles [call] gives, and the given roles that can't
  /// be read.
  static (Map<String, WcagColor>, Set<String>) _rolesOf(
    _Call call,
    _ColorEvaluator colors,
    bool isDark,
  ) {
    final given = <String, WcagColor>{};
    final unread = <String>{};
    for (final MapEntry(key: role, value: value) in _valuesOf(call).entries) {
      switch (colors.color(value, isDark: isDark)) {
        case final color?:
          given[role] = color;
        case null:
          unread.add(role);
      }
    }
    return (given, unread);
  }

  /// The roles [call] gives, each with the value it gives.
  static Map<String, Expression> _valuesOf(_Call call) => {
    for (final (name, value) in call.named)
      if (ColorRoles.isRole(name)) name: value,
  };
}
