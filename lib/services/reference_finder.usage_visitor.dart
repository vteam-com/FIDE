part of 'reference_finder.dart';

/// A use of a declaration: where its name starts, and how to list it.
typedef _Use = ({int offset, SearchResult result});

/// Finds outline declarations and the names in a unit that resolve to a
/// given element.
class _UsageVisitor extends GeneralizingAstVisitor<void> {
  _UsageVisitor._(this._target, this._unit, this._skip, this._renaming);

  /// Whether a field's `this.` parameters and their named arguments count
  /// as its uses, as they must be renamed with it.
  final bool _renaming;

  /// The source range of the declaration whose own text isn't searched.
  final ({int offset, int end})? _skip;

  final Element _target;

  final ResolvedUnitResult _unit;

  final List<_Use> _uses = [];

  /// The class, function, method or variable declaration of [unit]
  /// starting at [offset], as the outline lists them.
  static Declaration? declarationAt(CompilationUnit unit, int offset) {
    Declaration? found;
    void visit(AstNode node) {
      if (found != null) return;
      if (node.offset == offset &&
          (node is ClassDeclaration ||
              node is FunctionDeclaration ||
              node is MethodDeclaration ||
              node is VariableDeclaration)) {
        found = node as Declaration;
        return;
      }
      node.childEntities.whereType<AstNode>().forEach(visit);
    }

    visit(unit);
    return found;
  }

  /// Every name in [unit] resolving to [target], except within [skip];
  /// see [_renaming] for [renaming].
  static List<_Use> usesOf(
    Element target,
    ResolvedUnitResult unit, {
    required bool renaming,
    ({int offset, int end})? skip,
  }) {
    final visitor = _UsageVisitor._(target, unit, skip, renaming);
    unit.unit.accept(visitor);
    return visitor._uses;
  }

  /// Field and top-level variable uses resolve to their getter or setter;
  /// when renaming, a `this.` parameter (or its named argument) stands for
  /// its field.
  Element _declared(Element element) => switch (element) {
    PropertyAccessorElement(:final variable) => variable,
    FieldFormalParameterElement(:final field?) when _renaming => field,
    _ => element,
  };

  /// Whether [a] and [b] are the same declaration, even when resolved by
  /// different analysis contexts.
  static bool _same(Element a, Element b) =>
      identical(a, b) ||
      (a.kind == b.kind &&
          a.name == b.name &&
          a.library?.uri == b.library?.uri &&
          a.enclosingElement?.name == b.enclosingElement?.name);

  /// Records a use spanning [offset] and [length] when [element] is the
  /// target.
  void _check(Element? element, int offset, int length) {
    if (element == null || !_same(_declared(element), _declared(_target))) {
      return;
    }
    final location = _unit.lineInfo.getLocation(offset);
    final lineStart = offset - (location.columnNumber - 1);
    final lineBreak = _unit.content.indexOf('\n', lineStart);
    final lineContent = _unit.content
        .substring(lineStart, lineBreak == -1 ? null : lineBreak)
        .trimRight();
    final matchStart = location.columnNumber - 1;
    _uses.add((
      offset: offset,
      result: SearchResult(
        filePath: _unit.path,
        lineNumber: location.lineNumber,
        lineContent: lineContent,
        matchStart: matchStart,
        matchEnd: matchStart + length,
      ),
    ));
  }

  @override
  void visitComment(Comment node) {
    // Doc comment mentions aren't uses
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    if (_renaming) {
      _check(
        node.declaredFragment?.element,
        node.name.offset,
        node.name.length,
      );
    }
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    if (_renaming) {
      _check(node.correspondingParameter, node.name.offset, node.name.length);
    }
    super.visitNamedArgument(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _check(node.element, node.name.offset, node.name.length);
    super.visitNamedType(node);
  }

  @override
  void visitNode(AstNode node) {
    final skip = _skip;
    if (skip != null && node.offset == skip.offset && node.end == skip.end) {
      return;
    }
    super.visitNode(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _check(node.element, node.offset, node.length);
    super.visitSimpleIdentifier(node);
  }
}
