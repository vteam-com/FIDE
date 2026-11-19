part of 'color_contrast_analyzer.dart';

/// Gathers across the project what reading its colors needs: the
/// initializers of its constants, the color schemes and themes it builds,
/// and whether its app has a dark theme.
class _DeclarationCollector extends RecursiveAstVisitor<void> {
  /// Initializers of top-level and static constants and getters, by name
  /// and by class and name; a name two of them share is dropped.
  final Map<String, Expression> constants = {};

  /// Whether an app gives a `darkTheme`, so both themes render.
  bool hasDarkTheme = false;

  /// Each expression that may build a color scheme, with its file; a copy
  /// stands for the scheme it copies.
  final List<(Expression, _SourceFile)> schemes = [];

  /// The `ThemeData` calls, whose brightness tells which themes the app
  /// renders.
  final List<_Call> themes = [];

  /// The `themeMode` each app gives, such as `ThemeMode.dark`.
  final Set<String> themeModes = {};

  /// The project's classes, by name.
  final Map<String, ClassDeclaration> classes = {};

  /// Names two constants share, which name neither.
  final Set<String> _shared = {};

  /// The file being read.
  late _SourceFile _file;

  /// Reads [file]'s declarations and calls.
  void collect(_SourceFile file) {
    _file = file;
    file.unit.accept(this);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    classes[node.namePart.typeName.lexeme] = node;
    super.visitClassDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) {
      final owner = node
          .thisOrAncestorOfType<ClassDeclaration>()
          ?.namePart
          .typeName
          .lexeme;
      for (final variable in node.fields.variables) {
        _add(variable.name.lexeme, owner, variable.initializer);
      }
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _visitCall(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node case MethodDeclaration(
      isStatic: true,
      isGetter: true,
      body: ExpressionFunctionBody(:final expression),
    )) {
      final owner = node
          .thisOrAncestorOfType<ClassDeclaration>()
          ?.namePart
          .typeName
          .lexeme;
      _add(node.name.lexeme, owner, expression);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _visitCall(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      _add(variable.name.lexeme, null, variable.initializer);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  /// Keeps [initializer] as the constant [name] of the class [owner], or
  /// top-level when null.
  void _add(String name, String? owner, Expression? initializer) {
    if (initializer == null) return;
    if (owner != null) constants['$owner.$name'] = initializer;
    if (_shared.contains(name)) return;
    if (constants.containsKey(name)) {
      constants.remove(name);
      _shared.add(name);
    } else {
      constants[name] = initializer;
    }
  }

  /// Notes what the call [node] tells about the app's themes.
  void _visitCall(Expression node) {
    final call = _Call.of(node);
    if (call == null) return;
    if (call['darkTheme'] != null) hasDarkTheme = true;
    if (call['themeMode'] case final mode?) themeModes.add(mode.toSource());
    if (call.typeName == 'ThemeData') themes.add(call);
    final buildsScheme =
        call.typeName == 'ColorScheme' ||
        call.member == 'copyWith' ||
        (call.fullName == 'ThemeData' && call['colorSchemeSeed'] != null);
    if (buildsScheme && !_isCopied(node)) schemes.add((node, _file));
  }

  /// Whether [node] is the value a `copyWith` is called on, which the
  /// copy stands for.
  static bool _isCopied(Expression node) => switch (node.parent) {
    MethodInvocation(:final target, :final methodName) =>
      identical(target, node) && methodName.name == 'copyWith',
    _ => false,
  };
}
