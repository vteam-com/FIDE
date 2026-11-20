part of 'reference_finder.dart';

/// Finds what a name in resolved code refers to, for Go to Definition.
class _NameLocator {
  const _NameLocator._();

  /// What the name at the caret [offset] of [unit] refers to: the name the
  /// character after the caret is in, else the one before it, so a caret
  /// just past a name counts; null when neither is a resolved name.
  ///
  /// A constructor call's class name refers to the constructor called,
  /// and a `this.` or `super.` parameter to the field or parameter it
  /// fills.
  static Element? elementAt(CompilationUnit unit, int offset) =>
      _elementOf(_innermostAt(unit, offset), offset) ??
      _elementOf(_innermostAt(unit, offset - 1), offset - 1);

  /// The innermost node under [node] spanning the character at [offset].
  static AstNode _innermostAt(AstNode node, int offset) {
    for (final child in node.childEntities) {
      if (child is AstNode && child.offset <= offset && offset < child.end) {
        return _innermostAt(child, offset);
      }
    }
    return node;
  }

  /// What the name of [node] spanning the character at [offset] refers to,
  /// as declared (not a generic member's instantiation); null when no
  /// resolved name of [node] spans it.
  static Element? _elementOf(AstNode node, int offset) {
    bool spans(int start, int end) => start <= offset && offset < end;
    final element = switch (node) {
      SimpleIdentifier() => node.element ?? _written(node),
      NamedType(:final name, :final parent) when spans(name.offset, name.end) =>
        parent is ConstructorName ? parent.element : node.element,
      ImportPrefixReference() => node.element,
      NamedArgument(:final name) when spans(name.offset, name.end) =>
        node.correspondingParameter,
      FieldFormalParameter(:final name) when spans(name.offset, name.end) =>
        switch (node.declaredFragment?.element) {
          FieldFormalParameterElement(:final field) => field,
          _ => null,
        },
      SuperFormalParameter(:final name) when spans(name.offset, name.end) =>
        switch (node.declaredFragment?.element) {
          SuperFormalParameterElement(:final superConstructorParameter) =>
            superConstructorParameter,
          _ => null,
        },
      _ => null,
    };
    return element?.baseElement;
  }

  /// What [name] refers to when an assignment, `++` or `--` writes it,
  /// which the analyzer records on the writing expression, not the name.
  static Element? _written(SimpleIdentifier name) {
    // The name may be the property written, as in `a.b = 1`
    final target = switch (name.parent) {
      final PrefixedIdentifier prefixed when prefixed.identifier == name =>
        prefixed,
      final PropertyAccess access when access.propertyName == name => access,
      _ => name,
    };
    return switch (target.parent) {
      AssignmentExpression(:final leftHandSide, :final writeElement)
          when leftHandSide == target =>
        writeElement,
      PrefixExpression(:final operand, :final writeElement)
          when operand == target =>
        writeElement,
      PostfixExpression(:final operand, :final writeElement)
          when operand == target =>
        writeElement,
      _ => null,
    };
  }
}
