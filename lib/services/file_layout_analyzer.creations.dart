part of 'file_layout_analyzer.dart';

/// Collects the classes code creates, by name, and the widgets it opens
/// as a route: an app's `home`, what a page route or page builds and the
/// values of a `routes` table.
class _Creations extends RecursiveAstVisitor<void> {
  /// The calls whose `builder`, `pageBuilder` or `child` is a screen.
  static const Set<String> _routeCalls = {
    'CupertinoPage',
    'CupertinoPageRoute',
    'CustomTransitionPage',
    'GoRoute',
    'MaterialPage',
    'MaterialPageRoute',
    'NoTransitionPage',
    'PageRouteBuilder',
  };

  /// The arguments of a [_routeCalls] call naming its screen.
  static const Set<String> _routeArguments = {
    'builder',
    'child',
    'pageBuilder',
  };

  /// The argument of an app naming its first screen.
  static const String _homeArgument = 'home';

  /// The argument of an app mapping route names to screen builders.
  static const String _routesArgument = 'routes';

  /// The classes created, by name.
  final Set<String> created = {};

  /// The classes opened as a route, by name.
  final Set<String> routes = {};

  /// The names [node] creates, at any depth.
  static Set<String> of(AstNode node) => (_Creations()..visit(node)).created;

  /// Collects what [node] creates and opens.
  void visit(AstNode node) => node.accept(this);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _collect(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _collect(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    switch (node.name.lexeme) {
      case _homeArgument:
        routes.addAll(_screensOf(node.argumentExpression));
      case _routesArgument:
        if (node.argumentExpression case SetOrMapLiteral(:final elements)) {
          for (final entry in elements.whereType<MapLiteralEntry>()) {
            routes.addAll(_screensOf(entry.value));
          }
        }
    }
    super.visitNamedArgument(node);
  }

  /// Records the class [expression] creates, and the screens it opens
  /// when it is one of [_routeCalls].
  void _collect(Expression expression) {
    final creation = WidgetCreation.of(expression);
    if (creation == null) return;
    final name = creation.typeName;
    created.add(name);
    if (!_routeCalls.contains(name)) return;
    for (final argument
        in creation.arguments.arguments.whereType<NamedArgument>()) {
      if (_routeArguments.contains(argument.name.lexeme)) {
        routes.addAll(_screensOf(argument.argumentExpression));
      }
    }
  }

  /// The classes [expression] creates as a screen: itself, or what a
  /// builder function returns.
  static Iterable<String> _screensOf(Expression expression) {
    final returned = switch (expression) {
      FunctionExpression(body: ExpressionFunctionBody(:final expression)) => [
        expression,
      ],
      FunctionExpression(:final body) => _Returns.of(body),
      _ => [expression],
    };
    return [
      for (final each in returned)
        ?WidgetCreation.of(each.unParenthesized)?.typeName,
    ];
  }
}

/// Collects what a function body returns, leaving out the functions
/// declared in it.
class _Returns extends RecursiveAstVisitor<void> {
  /// The expressions returned.
  final List<Expression> returned = [];

  /// What [body] returns.
  static List<Expression> of(FunctionBody body) =>
      (_Returns()..visit(body)).returned;

  /// Collects what [node] returns.
  void visit(AstNode node) => node.accept(this);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (node.expression case final expression?) returned.add(expression);
  }
}
