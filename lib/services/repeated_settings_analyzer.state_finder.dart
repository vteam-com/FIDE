part of 'repeated_settings_analyzer.dart';

/// Finds the parts of an expression reading the code's own state: its
/// locals, parameters and instance members, and what is read from them;
/// the [RepeatedSettingsAnalyzer] compares those by shape only.
class _StateFinder extends RecursiveAstVisitor<void> {
  /// The expressions found, outermost only.
  final List<Expression> found = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) =>
      _isState(node) ? found.add(node) : super.visitPrefixedIdentifier(node);

  @override
  void visitPropertyAccess(PropertyAccess node) =>
      _isState(node) ? found.add(node) : super.visitPropertyAccess(node);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!isMemberName(node) && node.parent is! Label && _isState(node)) {
      found.add(node);
    }
  }

  /// Whether [node] names a member of the object before it, such as the
  /// `colorScheme` of `Theme.of(context).colorScheme`, rather than
  /// standing on its own.
  static bool isMemberName(SimpleIdentifier node) => switch (node.parent) {
    PrefixedIdentifier(:final identifier) => identifier == node,
    PropertyAccess(:final propertyName) => propertyName == node,
    MethodInvocation(:final methodName, :final target) =>
      methodName == node && target != null,
    _ => false,
  };

  @override
  void visitThisExpression(ThisExpression node) => found.add(node);

  /// Whether [expression] reads state, or a property of state.
  static bool _isState(Expression expression) => switch (expression) {
    ThisExpression() => true,
    ParenthesizedExpression(:final expression) => _isState(expression),
    SimpleIdentifier(:final element) => _isStateElement(element),
    PrefixedIdentifier(:final prefix, :final identifier) =>
      _isState(prefix) && identifier.element is! MethodElement,
    PropertyAccess(:final target?) => _isState(target),
    _ => false,
  };

  /// Whether [element] is a local, a parameter or an instance member.
  static bool _isStateElement(Element? element) => switch (element) {
    LocalVariableElement() || FormalParameterElement() => true,
    PropertyAccessorElement(:final isStatic, :final enclosingElement) =>
      !isStatic && enclosingElement is InstanceElement,
    FieldElement(:final isStatic) => !isStatic,
    _ => false,
  };
}
