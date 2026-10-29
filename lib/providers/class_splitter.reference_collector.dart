part of 'class_splitter.dart';

/// A resolved name used in source: the [element] it names, the top-level
/// declaration holding it, and the import prefix it was written with.
///
/// [needsImport] is true when the name resolves through the library's
/// import scope (a top-level declaration or an extension member) rather
/// than through an object's members.
typedef _Reference = ({
  Element element,
  Element top,
  String? prefix,
  bool needsImport,
});

/// Collects every resolved [_Reference] under a node, skipping doc comments
/// and, optionally, one declaration.
class _ReferenceCollector extends GeneralizingAstVisitor<void> {
  _ReferenceCollector._(this._skip);

  /// The declaration whose references are left out, if any.
  final AstNode? _skip;

  final List<_Reference> _references = [];

  /// References made under [node], except under [skip].
  static List<_Reference> collect(AstNode node, {AstNode? skip}) {
    final collector = _ReferenceCollector._(skip);
    node.accept(collector);
    return collector._references;
  }

  /// The declaration directly under a library holding [element], or null
  /// for libraries, import prefixes and elements outside any library.
  static Element? _topLevelOf(Element element) {
    if (element is PrefixElement || element is LibraryElement) return null;
    Element? top = element;
    while (top != null && top.enclosingElement is! LibraryElement) {
      top = top.enclosingElement;
    }
    return top;
  }

  /// Records a use of [element] written with [prefix].
  void _add(Element? element, String? prefix) {
    if (element == null) return;
    final top = _topLevelOf(element);
    if (top == null || top.library == null) return;
    final enclosing = element.enclosingElement;
    _references.add((
      element: element,
      top: top,
      prefix: prefix,
      needsImport: enclosing is LibraryElement || enclosing is ExtensionElement,
    ));
  }

  /// The import prefix [node] is qualified with (`p` in `p.join`), if any.
  static String? _prefixOf(SimpleIdentifier node) {
    final parent = node.parent;
    final target = switch (parent) {
      PrefixedIdentifier(:final prefix, :final identifier)
          when identifier == node =>
        prefix,
      MethodInvocation(:final target, :final methodName)
          when methodName == node =>
        target,
      _ => null,
    };
    if (target is SimpleIdentifier && target.element is PrefixElement) {
      return target.name;
    }
    return null;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _add(node.element, null);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _add(node.element, null);
    super.visitBinaryExpression(node);
  }

  @override
  void visitComment(Comment node) {
    // Doc comment references don't need imports to compile
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _add(node.element, null);
    super.visitIndexExpression(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _add(node.element, node.importPrefix?.name.lexeme);
    super.visitNamedType(node);
  }

  @override
  void visitNode(AstNode node) {
    if (identical(node, _skip)) return;
    super.visitNode(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _add(node.element, null);
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _add(node.element, null);
    super.visitPrefixExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _add(node.element, _prefixOf(node));
    super.visitSimpleIdentifier(node);
  }
}
