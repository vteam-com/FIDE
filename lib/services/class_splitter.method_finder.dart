part of 'class_splitter.dart';

/// Finds a unit's method declarations of a given name, in any class.
class _MethodFinder extends RecursiveAstVisitor<void> {
  _MethodFinder._(this._name);

  final String _name;

  final List<MethodDeclaration> _methods = [];

  /// The methods named [name] that [unit] declares, in source order.
  static List<MethodDeclaration> of(CompilationUnit unit, String name) {
    final finder = _MethodFinder._(name);
    unit.accept(finder);
    return finder._methods;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == _name) _methods.add(node);
    super.visitMethodDeclaration(node);
  }
}
