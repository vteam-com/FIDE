part of 'color_contrast_analyzer.dart';

/// Counts across the project each color its code writes, in each theme
/// the app renders: every outermost expression read as a color, such as
/// `Colors.grey.shade600` or `colorScheme.onSurface.withOpacity(0.6)`.
///
/// A top-level or static constant's own value names a color rather than
/// uses it: the constant counts where the code reads it.
class _ColorUseCollector extends GeneralizingAstVisitor<void> {
  _ColorUseCollector(this._theme);

  final _ProjectTheme _theme;

  /// Each color, keyed by its value in each theme, with the names it is
  /// written as and how many times.
  final Map<String, (List<WcagColor>, Map<String, int>)> _uses = {};

  /// The colors written, the most used first, then by value.
  List<ColorUsage> get usages {
    final usages = [
      for (final (colors, names) in _uses.values)
        ColorUsage(
          colors: colors,
          names: Map.fromEntries(
            names.entries.toList()..sort((a, b) => b.value - a.value),
          ),
        ),
    ];
    return usages..sort(
      (a, b) => a.count == b.count
          ? a.colors.first.argb.compareTo(b.colors.first.argb)
          : b.count - a.count,
    );
  }

  /// Counts the colors [file] writes.
  void collect(_SourceFile file) => file.unit.accept(this);

  @override
  void visitExpression(Expression node) {
    if (node.parent is CommentReference) return;
    final values = _mayBeColor(node) ? _valuesOf(node) : null;
    if (values == null) {
      super.visitExpression(node);
      return;
    }
    if (_isConstantValue(node)) return;
    final colors = values.toSet().length == 1 ? [values.first] : values;
    final (_, names) = _uses.putIfAbsent(
      colors.map((color) => color.hex).join(' '),
      () => (colors, {}),
    );
    final name = _theme.colors.nameOf(node);
    names[name] = (names[name] ?? 0) + 1;
  }

  /// Whether [node] is a kind of expression that may be a color: a call,
  /// a member, an index, or the name of a constant read as a value.
  bool _mayBeColor(Expression node) => switch (node) {
    InstanceCreationExpression() ||
    MethodInvocation() ||
    PrefixedIdentifier() ||
    PropertyAccess() ||
    IndexExpression() ||
    PostfixExpression() => true,
    SimpleIdentifier(:final name, :final parent) =>
      _theme.colors.isConstant(name) &&
          !(parent is PrefixedIdentifier ||
              parent is PropertyAccess ||
              parent is ConstructorName ||
              parent is Label ||
              parent is Combinator ||
              (parent is MethodInvocation &&
                  identical(parent.methodName, node))),
    _ => false,
  };

  /// [node]'s color in each theme the app renders; null when it is not a
  /// color that can be read.
  List<WcagColor>? _valuesOf(Expression node) {
    final values = <WcagColor>[];
    for (final isDark in _theme.brightnesses) {
      final color = _theme.colors.color(node, isDark: isDark);
      if (color == null) return null;
      values.add(color);
    }
    return values;
  }

  /// Whether [node] is the value of a top-level or static constant, or of
  /// a static getter.
  static bool _isConstantValue(Expression node) => switch (node.parent) {
    VariableDeclaration(parent: VariableDeclarationList(:final parent)) =>
      parent is TopLevelVariableDeclaration ||
          (parent is FieldDeclaration && parent.isStatic),
    ExpressionFunctionBody(parent: MethodDeclaration(:final isStatic)) =>
      isStatic,
    _ => false,
  };
}
