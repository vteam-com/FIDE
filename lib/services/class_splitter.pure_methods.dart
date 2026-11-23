part of 'class_splitter.dart';

/// Plans moving the methods of a widget's `State` that use nothing of it
/// out of it, as top-level functions of its library, right after it:
/// they are no part of the widget's state, so tests can call them
/// directly instead of reaching into the `State`.
///
/// A method moves when it is public, an instance method that overrides
/// none, uses no instance member of the `State` or of Flutter's `State`
/// (`widget`, `context`, `setState`…), nor `this` or `super`, and no
/// top-level declaration of the library takes its name; the static
/// members of the `State` it uses get qualified with the class name.
class _PureMethods {
  /// Creates the plan for [_state], a widget's `State` declared in
  /// [_unit].
  _PureMethods(this._unit, this._state);

  /// The annotation marking a method overriding another.
  static const String _override = 'override';

  final ClassDeclaration _state;

  final ResolvedUnitResult _unit;

  /// The methods among [names] that move, with the text edits of [_unit]
  /// moving them; none when none can.
  ({Set<String> moved, Map<int, (int, String)> edits}) plan(Set<String> names) {
    final element = _state.declaredFragment!.element;
    final scope = _unit.unit.declaredFragment!.scope;
    final methods = [
      for (final member in _state.body.members.whereType<MethodDeclaration>())
        if (names.contains(member.name.lexeme) &&
            !Identifier.isPrivateName(member.name.lexeme) &&
            !member.isStatic &&
            !member.isGetter &&
            !member.isSetter &&
            !member.isOperator &&
            !member.metadata.any(
              (annotation) => annotation.name.name == _override,
            ) &&
            scope.lookup(member.name.lexeme).getter == null &&
            !_InstanceUses.anyIn(member, element))
          member,
    ];
    if (methods.isEmpty) return (moved: const {}, edits: const {});

    final content = _unit.content;
    final edits = <int, (int, String)>{};
    final functions = <String>[];
    for (final method in methods) {
      final start = TextOffsets.lineStartOf(content, method.offset);
      final end = TextOffsets.lineEndAfter(content, method.end);
      final text = TextOffsets.applyEdits(content.substring(start, end), {
        for (final name in _InstanceUses.unqualifiedStatics(method, element))
          // `$_suffix` in a string takes braces: `${Foo._suffix}`
          if (name.parent case InterpolationExpression(rightBracket: null)) ...{
            name.offset - start: (0, '{${element.name}.'),
            name.end - start: (0, '}'),
          } else
            name.offset - start: (0, '${element.name}.'),
      });
      functions.add(_dedented(text).trimRight());
      final removed = _Planner._tidied(content, (offset: start, end: end));
      edits[removed.offset] = (removed.end - removed.offset, '');
    }
    edits[_state.end] = (0, '\n\n${functions.join('\n\n')}');
    return (
      moved: {for (final method in methods) method.name.lexeme},
      edits: edits,
    );
  }

  /// [text], a class member's lines, without the indentation its first
  /// line has.
  static String _dedented(String text) {
    final lines = text.split('\n');
    final indent = lines.first.length - lines.first.trimLeft().length;
    return [
      for (final line in lines)
        line.length >= indent && line.substring(0, indent).trim().isEmpty
            ? line.substring(indent)
            : line.trimLeft(),
    ].join('\n');
  }
}

/// Finds, in a method of a widget's `State`, what ties it to the `State`:
/// `this`, `super`, or an instance member of the `State` or of a class it
/// extends; and the static members of the `State` it names unqualified.
class _InstanceUses extends RecursiveAstVisitor<void> {
  _InstanceUses._(this._state);

  final InterfaceElement _state;

  bool _found = false;

  final List<SimpleIdentifier> _statics = [];

  /// Whether [method] uses something of [state]'s instance.
  static bool anyIn(MethodDeclaration method, InterfaceElement state) {
    final uses = _InstanceUses._(state);
    method.accept(uses);
    return uses._found;
  }

  /// The names [method] gives a static member of [state] without its
  /// class.
  static List<SimpleIdentifier> unqualifiedStatics(
    MethodDeclaration method,
    InterfaceElement state,
  ) {
    final uses = _InstanceUses._(state);
    method.accept(uses);
    return uses._statics;
  }

  /// Whether [element] is declared by the `State` or a class it extends.
  bool _isOfState(Element? element) {
    final owner = element?.enclosingElement;
    return owner is InterfaceElement &&
        (owner == _state ||
            _state.allSupertypes.any((type) => type.element == owner));
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = switch (node.parent) {
      AssignmentExpression(:final leftHandSide, :final writeElement)
          when leftHandSide == node =>
        writeElement,
      _ => node.element,
    };
    final isStatic = switch (element) {
      ExecutableElement(:final isStatic) => isStatic,
      FieldElement(:final isStatic) => isStatic,
      _ => true,
    };
    if (_isOfState(element)) {
      if (!isStatic) {
        _found = true;
      } else if (element?.enclosingElement == _state && !_isQualified(node)) {
        _statics.add(node);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitSuperExpression(SuperExpression node) => _found = true;

  @override
  void visitThisExpression(ThisExpression node) => _found = true;

  /// Whether [node] is written after a target: `Foo.bar`, `a.bar`.
  static bool _isQualified(SimpleIdentifier node) => switch (node.parent) {
    PrefixedIdentifier(:final identifier) => identifier == node,
    PropertyAccess(:final propertyName) => propertyName == node,
    MethodInvocation(:final methodName, :final target) =>
      methodName == node && target != null,
    _ => false,
  };
}
