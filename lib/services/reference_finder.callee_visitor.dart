part of 'reference_finder.dart';

/// Collects what a declaration calls: the functions, methods, constructors
/// and explicit getters and setters its code names, called or torn off,
/// each once, in the order first named; a field's getter or a function
/// declared inside it is no call.
class _CalleeVisitor extends RecursiveAstVisitor<void> {
  /// What was named so far, in that order.
  final Set<ExecutableElement> _callees = {};

  /// What [declaration] calls; see [_CalleeVisitor].
  static Set<ExecutableElement> calleesOf(Declaration declaration) {
    final visitor = _CalleeVisitor();
    declaration.accept(visitor);
    return visitor._callees;
  }

  /// Records [element] when it is a call's target.
  void _add(Element? element) {
    if (element?.baseElement case final ExecutableElement callee
        when callee is! LocalFunctionElement &&
            (callee is! PropertyAccessorElement ||
                callee.isOriginDeclaration)) {
      _callees.add(callee);
    }
  }

  @override
  void visitComment(Comment node) {
    // Doc comment mentions aren't calls
  }

  @override
  void visitConstructorName(ConstructorName node) {
    _add(node.element);
    super.visitConstructorName(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _add(_NameLocator.referencedBy(node));
    super.visitSimpleIdentifier(node);
  }
}
