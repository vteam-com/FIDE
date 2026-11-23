part of 'class_splitter.dart';

/// Plans removing every reach into a widget's `State` from a resolved
/// test unit, as a widget's `State` is private to its widget and a test
/// checks the widget itself.
///
/// What goes: each statement reaching into it (`tester.state<FooState>(…)`,
/// `widget.createState()`, its members, a variable holding it, even
/// `dynamic`), in a test, a `setUp` or `tearDown`, a `group` or `main`,
/// with the comment lines right above it; the statements using what those
/// declared, and the locals only they used; a test, hook or group left
/// empty; and the imports only what goes used.
class _TestCleaner {
  /// Creates the cleaner of [_unit] for [_state], a widget's `State`,
  /// whose methods [_movedOut] moved out of it, as top-level functions.
  _TestCleaner(this._unit, this._state, {this._movedOut = const {}});

  /// The functions whose callback holds a test's or a group's statements.
  static const Set<String> _callbacks = {
    'test',
    'testWidgets',
    'group',
    'setUp',
    'setUpAll',
    'tearDown',
    'tearDownAll',
  };

  /// The function running a test file.
  static const String _main = 'main';

  final Set<String> _movedOut;

  final InterfaceElement _state;

  final ResolvedUnitResult _unit;

  /// The methods the unit calls on the `State`, by name, as
  /// `state.formatBytes(0)`: those using nothing of it can move out of it.
  Set<String> calledMethods() {
    final (:reaches, :invocations) = _ReachFinder.of(_unit.unit, _state);
    return {
      for (final invocation in invocations)
        if (_ReachFinder._holds(invocation.target!, reaches))
          invocation.methodName.name,
    };
  }

  /// The ranges to remove, and how many statements reaching into the
  /// `State` they hold; none when the unit doesn't reach into it.
  ///
  /// Throws a [ClassSplitException] when it reaches into it outside a
  /// test, hook, group or `main`, such as in a helper, which can't go
  /// whole.
  ({List<_Removal> removals, int statements}) plan() {
    final found = _ReachFinder.of(_unit.unit, _state);
    // A call of a method moved out of the State loses its target, the
    // State: `state.formatBytes(0)` becomes `formatBytes(0)`
    final calls = [
      for (final invocation in found.invocations)
        if (_movedOut.contains(invocation.methodName.name) &&
            _ReachFinder._holds(invocation.target!, found.reaches))
          invocation,
    ];
    final targets = [for (final call in calls) call.target!];
    final reaches = [
      for (final reach in found.reaches)
        if (!targets.any((target) => _contains(target, reach))) reach,
    ];
    if (reaches.isEmpty && calls.isEmpty) {
      return (removals: const [], statements: 0);
    }

    // The statements of each body that go, and the calls whose callback,
    // an expression, goes whole
    final doomed = <Block, Set<Statement>>{};
    final removed = <Statement>{};
    for (final reach in reaches) {
      switch (_statementOf(reach)) {
        case (final Block body, final Statement statement):
          (doomed[body] ??= {}).add(statement);
        case (null, final Statement call):
          removed.add(call);
      }
    }
    final reaching =
        removed.length +
        doomed.values.fold<int>(0, (sum, set) => sum + set.length);
    for (final MapEntry(key: body, value: statements) in doomed.entries) {
      _addDependents(body, statements, targets);
      removed.addAll(statements);
    }
    _removeEmptied(removed);

    final content = _unit.content;
    return (
      removals: [
        for (final node in removed)
          if (!removed.any((other) => other != node && _contains(other, node)))
            _rangeOf(content, node),
        for (final call in calls)
          if (!removed.any((node) => _contains(node, call)))
            (offset: call.target!.offset, end: call.operator!.end),
        ..._unusedImports(removed, keepsState: calls.isNotEmpty),
      ],
      statements: reaching,
    );
  }

  /// Adds to [doomed], statements of [body], those using what a doomed
  /// one declares, then the declarations of locals only doomed ones use,
  /// until none is left to add; the [targets] calls lose aren't uses.
  static void _addDependents(
    Block body,
    Set<Statement> doomed,
    List<Expression> targets,
  ) {
    Set<Element> usesOf(AstNode node) => _Uses.of(node, skip: targets);
    var grew = true;
    while (grew) {
      grew = false;
      final declaredByDoomed = {
        for (final statement in doomed) ..._localsOf(statement),
      };
      for (final statement in body.statements) {
        if (doomed.contains(statement)) continue;
        final declared = _localsOf(statement);
        final usesDoomed = usesOf(statement).any(declaredByDoomed.contains);
        // Declared for the doomed statements alone
        final onlyForDoomed =
            declared.isNotEmpty &&
            declared.every(
              (local) =>
                  doomed.any((other) => usesOf(other).contains(local)) &&
                  !body.statements.any(
                    (other) =>
                        other != statement &&
                        !doomed.contains(other) &&
                        usesOf(other).contains(local),
                  ),
            );
        if (usesDoomed || onlyForDoomed) {
          doomed.add(statement);
          grew = true;
        }
      }
    }
  }

  /// Whether [outer] spans [inner].
  static bool _contains(AstNode outer, AstNode inner) =>
      outer.offset <= inner.offset && inner.end <= outer.end;

  /// The test, hook or group call statement whose callback is [function];
  /// null when it is none's.
  static ExpressionStatement? _callOf(AstNode? function) {
    if (function is! FunctionExpression) return null;
    final invocation = function.parent?.parent;
    if (invocation is! MethodInvocation ||
        !_callbacks.contains(invocation.methodName.name)) {
      return null;
    }
    return switch (invocation.parent) {
      final ExpressionStatement statement => statement,
      _ => null,
    };
  }

  /// Whether [block] is the body of a test, hook or group callback, or of
  /// `main`, whose statements can go one by one.
  static bool _isCleanable(Block block) {
    final function = block.parent?.parent;
    return _callOf(function) != null ||
        switch (function?.parent) {
          FunctionDeclaration(:final name) => name.lexeme == _main,
          _ => false,
        };
  }

  /// The local variables [statement] declares.
  static Set<Element> _localsOf(Statement statement) => {
    if (statement case VariableDeclarationStatement(:final variables))
      for (final variable in variables.variables)
        ?variable.declaredFragment?.element,
  };

  /// [node]'s whole lines, with the comment lines right above it, and a
  /// blank line around it when it is between two.
  static _Removal _rangeOf(String content, AstNode node) {
    final comment = node.beginToken.precedingComments;
    final start = comment == null ? node.offset : comment.offset;
    return _Planner._tidied(content, (
      offset: TextOffsets.lineStartOf(content, start),
      end: TextOffsets.lineEndAfter(content, node.end),
    ));
  }

  /// Adds to [removed] each test, hook or group call whose callback's
  /// statements all go, until none is left to add.
  static void _removeEmptied(Set<Statement> removed) {
    var grew = true;
    while (grew) {
      grew = false;
      final bodies = {
        for (final statement in removed)
          if (statement.parent case final Block body) body,
      };
      for (final body in bodies) {
        final call = _callOf(body.parent?.parent);
        if (call != null &&
            !removed.contains(call) &&
            body.statements.every(removed.contains)) {
          removed.add(call);
          grew = true;
        }
      }
    }
  }

  /// The body holding [reach] and its statement there, the innermost a
  /// test, hook, group or `main` holds; for a callback that is an
  /// expression, no body and the call, which goes whole.
  ///
  /// Throws a [ClassSplitException] when [reach] is in none of them.
  (Block?, Statement) _statementOf(AstNode reach) {
    for (AstNode? node = reach; node != null; node = node.parent) {
      final parent = node.parent;
      if (node is Statement && parent is Block && _isCleanable(parent)) {
        return (parent, node);
      }
      if (node is ExpressionFunctionBody) {
        if (_callOf(node.parent) case final call?) return (null, call);
      }
    }
    final line = _unit.lineInfo.getLocation(reach.offset).lineNumber;
    throw ClassSplitException(
      '${p.basename(_unit.path)}:$line reaches into ${_state.name} outside '
      'a test; check its widget there instead first',
    );
  }

  /// The import lines only [removed] used; never the `State`'s library's
  /// when [keepsState], as calls of the methods moved out of it use it.
  List<_Removal> _unusedImports(
    Set<AstNode> removed, {
    required bool keepsState,
  }) {
    final before = DartReferenceCollector.collect(_unit.unit);
    final after = DartReferenceCollector.collect(_unit.unit, skip: removed);
    bool uses(List<DartReference> references, ImportDirective directive) =>
        references.any(
          (reference) =>
              reference.needsImport && _Planner._provides(directive, reference),
        );
    return [
      for (final directive
          in _unit.unit.directives.whereType<ImportDirective>())
        if (uses(before, directive) &&
            !uses(after, directive) &&
            !(keepsState &&
                directive.libraryImport?.importedLibrary == _state.library))
          _Planner._lineRange(_unit.content, directive),
    ];
  }
}

/// Finds where a unit reaches into a widget's `State`: a type naming it,
/// or a private name a test can't reach, which doesn't resolve, by its
/// name; an expression of its type, such as `tester.state<FooState>(…)`;
/// its widget's `createState()`, whatever type it declares; and a variable
/// holding one, even `dynamic`, as declared, assigned and used.
class _ReachFinder extends RecursiveAstVisitor<void> {
  _ReachFinder._(this._state) : _widget = WidgetStates.widgetOf(_state);

  /// The method of a stateful widget making its `State`.
  static const String _createState = 'createState';

  /// The widget [_state] belongs to.
  final InterfaceElement? _widget;

  final List<AssignmentExpression> _assignments = [];

  final List<MethodInvocation> _invocations = [];

  final List<VariableDeclaration> _declarations = [];

  final List<SimpleIdentifier> _identifiers = [];

  final List<AstNode> _reaches = [];

  final InterfaceElement _state;

  /// The nodes of [unit] reaching into [state], and its calls of a
  /// method on a target, which may be one of them.
  static ({List<AstNode> reaches, List<MethodInvocation> invocations}) of(
    CompilationUnit unit,
    InterfaceElement state,
  ) {
    final finder = _ReachFinder._(state);
    unit.accept(finder);
    return (reaches: finder._withHolders(), invocations: finder._invocations);
  }

  /// Whether [node] holds one of [reaches].
  static bool _holds(AstNode node, Iterable<AstNode> reaches) => reaches.any(
    (reach) => node.offset <= reach.offset && reach.end <= node.end,
  );

  /// The reaches with the variables holding a `State`, those given an
  /// expression reaching into it, until none is left to add: each one's
  /// declaration and uses.
  List<AstNode> _withHolders() {
    final reaches = {..._reaches};
    final holders = <Element>{};
    var grew = true;
    while (grew) {
      grew = false;
      for (final declaration in _declarations) {
        final element = declaration.declaredFragment?.element;
        final initializer = declaration.initializer;
        if (element != null &&
            !holders.contains(element) &&
            initializer != null &&
            _holds(initializer, reaches)) {
          holders.add(element);
          grew = true;
        }
      }
      for (final assignment in _assignments) {
        final element = assignment.writeElement;
        if (element != null &&
            !holders.contains(element) &&
            _holds(assignment.rightHandSide, reaches)) {
          holders.add(element);
          grew = true;
        }
      }
      for (final identifier in _identifiers) {
        if (holders.contains(identifier.element) ||
            holders.contains(switch (identifier.parent) {
              AssignmentExpression(:final writeElement) => writeElement,
              _ => null,
            })) {
          grew = reaches.add(identifier) || grew;
        }
      }
      for (final declaration in _declarations) {
        if (holders.contains(declaration.declaredFragment?.element)) {
          grew = reaches.add(declaration) || grew;
        }
      }
    }
    return reaches.toList();
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _assignments.add(node);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final isOfState = switch (node.staticType) {
      InterfaceType(:final element) => element == _state,
      _ => false,
    };
    // Its widget's `createState()`, whatever type it declares
    final makesState =
        node.methodName.name == _createState &&
        switch (node.realTarget?.staticType) {
          InterfaceType(:final element) => element == _widget,
          _ => false,
        };
    if (isOfState || makesState) _reaches.add(node);
    if (node.target != null) _invocations.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final element = node.element;
    if (element == _state ||
        (element == null && node.name.lexeme == _state.name)) {
      _reaches.add(node);
    }
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _identifiers.add(node);
    if (node.staticType case InterfaceType(:final element)
        when element == _state) {
      _reaches.add(node);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _declarations.add(node);
    super.visitVariableDeclaration(node);
  }
}

/// Collects the locals a node uses.
class _Uses extends RecursiveAstVisitor<void> {
  final Set<Element> _locals = {};

  /// The nodes whose uses don't count.
  List<AstNode> _skip = const [];

  /// The local variables [node] reads or writes, outside [skip].
  static Set<Element> of(AstNode node, {List<AstNode> skip = const []}) {
    final uses = _Uses().._skip = skip;
    node.accept(uses);
    return uses._locals;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element case final LocalVariableElement local
        when !_skip.any(
          (skipped) => skipped.offset <= node.offset && node.end <= skipped.end,
        )) {
      _locals.add(local);
    }
    super.visitSimpleIdentifier(node);
  }
}
