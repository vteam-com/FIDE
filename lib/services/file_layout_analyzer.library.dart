part of 'file_layout_analyzer.dart';

/// A library of the project's `lib` folder, its file and parts, with what
/// the layout review asks of it: what it declares, imports and creates.
class _Library {
  _Library(
    this.file, {
    required Map<String, ParsedSourceFile> files,
    required String projectPath,
    required String? packageName,
  }) : relativePath = p.posix.joinAll(
         p.split(p.relative(file.path, from: projectPath)),
       ) {
    for (final directive in file.unit.directives) {
      if (directive is! UriBasedDirective) continue;
      final uri = directive.uri.stringValue;
      if (uri == null) continue;
      final path = switch (ImportGraph.resolve(
        uri,
        from: relativePath,
        packageName: packageName,
      )) {
        final relative? => p.joinAll([projectPath, ...p.posix.split(relative)]),
        null => null,
      };
      if (directive is PartDirective) {
        if (path != null && File(path).existsSync()) parts.add(path);
      } else if (path != null) {
        dependencies.add(path);
      } else {
        externalUris.add(uri);
      }
    }
    units = [file.unit, for (final part in parts) ?files[part]?.unit];
    final creations = _Creations();
    for (final unit in units) {
      creations.visit(unit);
      for (final declaration in unit.declarations) {
        switch (declaration) {
          case ClassDeclaration():
            classes.add(declaration);
          case FunctionDeclaration(:final name) when name.lexeme == _main:
            declaresMain = true;
          default:
        }
      }
      if (!hasAsync) hasAsync = _Async.isIn(unit);
    }
    created = creations.created;
    routes = creations.routes;
  }

  /// The name of a program's entry point.
  static const String _main = 'main';

  /// The classes the library declares, in its file then its parts.
  final List<ClassDeclaration> classes = [];

  /// Absolute paths of the project files the library imports or exports.
  final Set<String> dependencies = {};

  /// Whether the library declares `main`, the app's entry point.
  bool declaresMain = false;

  /// The URIs of the libraries outside the project it imports or exports.
  final Set<String> externalUris = {};

  /// The library's own file.
  final ParsedSourceFile file;

  /// The project-relative path of [file], with `/` separators.
  final String relativePath;

  /// Whether the library runs async code or declares any: an `async`
  /// body, or a `Future` or `Stream` returned.
  bool hasAsync = false;

  /// Absolute paths of its parts on disk, generated ones too.
  final List<String> parts = [];

  /// The classes the library creates, by name.
  late final Set<String> created;

  /// The classes the library opens as a route, by name.
  late final Set<String> routes;

  /// The parsed code of its file and hand-written parts.
  late final List<CompilationUnit> units;

  /// The public types the library declares, in order.
  Iterable<CompilationUnitMember> get publicTypes => [
    for (final unit in units)
      for (final declaration in unit.declarations)
        if (typeNameOf(declaration) case final name?
            when !Identifier.isPrivateName(name))
          declaration,
  ];

  /// The name of the type [declaration] declares; null when it declares
  /// none.
  static String? typeNameOf(CompilationUnitMember declaration) =>
      switch (declaration) {
        ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
        EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
        ExtensionTypeDeclaration(:final namePart) => namePart.typeName.lexeme,
        MixinDeclaration(:final name) => name.lexeme,
        _ => null,
      };
}

/// Finds async code: an `async` body, or a declared `Future`, `FutureOr`
/// or `Stream` result.
class _Async extends RecursiveAstVisitor<void> {
  /// The result types that make a declaration async.
  static final RegExp _asyncType = RegExp(r'^(?:Future|FutureOr|Stream)\b');

  bool _found = false;

  /// Whether [unit] has async code.
  static bool isIn(CompilationUnit unit) {
    final finder = _Async();
    unit.accept(finder);
    return finder._found;
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    if (node.isAsynchronous) _found = true;
    if (!_found) super.visitBlockFunctionBody(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    if (node.isAsynchronous) _found = true;
    if (!_found) super.visitExpressionFunctionBody(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _check(node.returnType);
    if (!_found) super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(node.returnType);
    if (!_found) super.visitMethodDeclaration(node);
  }

  /// Records [type] when it is async.
  void _check(TypeAnnotation? type) {
    if (type != null && _asyncType.hasMatch(type.toSource())) _found = true;
  }
}
