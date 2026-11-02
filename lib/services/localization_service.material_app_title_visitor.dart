part of 'localization_service.dart';

/// Finds the string literal passed as `title:` to `MaterialApp`.
///
/// Without type resolution `MaterialApp(...)` parses as a method invocation;
/// only `const`/`new MaterialApp(...)` parses as an instance creation, so
/// both node types are checked.
class _MaterialAppTitleVisitor extends GeneralizingAstVisitor<void> {
  static const String _widgetName = 'MaterialApp';

  /// The title found, if any.
  String? title;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.toString() == _widgetName) {
      _readTitle(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == _widgetName) {
      _readTitle(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  /// Records the first string-literal `title:` argument in [arguments].
  void _readTitle(ArgumentList arguments) {
    if (title != null) return;
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'title') {
        final expression = argument.argumentExpression;
        if (expression is StringLiteral) {
          title = expression.stringValue;
          return;
        }
      }
    }
  }
}
