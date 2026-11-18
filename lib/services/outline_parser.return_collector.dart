part of 'outline_parser.dart';

/// Collects what a function body returns, leaving out the returns of the
/// closures and local functions inside it, which return for themselves.
class _ReturnCollector extends RecursiveAstVisitor<void> {
  /// The returned expressions, in source order.
  final List<Expression> _returned = [];

  /// What [body] returns: its expression for `=>`, else the expression of
  /// each of its own `return` statements.
  static List<Expression> returnedBy(FunctionBody body) {
    if (body is ExpressionFunctionBody) return [body.expression];
    final collector = _ReturnCollector();
    body.visitChildren(collector);
    return collector._returned;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Its returns are the closure's, not the body's
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    final expression = node.expression;
    if (expression != null) _returned.add(expression);
  }
}
