part of 'reference_finder.dart';

/// `State` methods where `context` exists but inherited widgets, such as
/// localizations, cannot be looked up yet or anymore.
const Set<String> _contextlessStateMethods = {'initState', 'dispose'};

/// Finds, in the background analysis, the `String` field a string argument
/// fills, with everything passed to it and every read of it.
extension _LookupFields on _ReferenceWorker {
  /// See [ReferenceFinder.lookupField].
  Future<LookupField> _lookupField(String filePath, int offset) async {
    final unit = await _resolvedUnit(filePath);
    if (unit == null) throw StateError('Can\'t analyze $filePath');
    final argument = _argumentAt(unit.unit, offset);
    final field = _fieldFilledBy(argument);
    if (field == null) {
      throw StateError('it is not passed to a field of a class');
    }
    final name = field.name ?? '';
    if (!field.isFinal || field.isStatic) {
      throw StateError('$name is not a final instance field');
    }
    if (!field.type.isDartCoreString ||
        field.type.nullabilitySuffix != NullabilitySuffix.none) {
      throw StateError('$name is not a String');
    }
    final declarationPath = field.firstFragment.libraryFragment.source.fullName;
    final declarationUnit = await _resolvedUnit(declarationPath);
    final type = declarationUnit == null
        ? null
        : _FieldUseVisitor.typeOf(declarationUnit.unit, field);
    if (type == null) throw StateError('$name has no String type to change');

    final arguments = <LookupFieldArgument>[];
    final reads = <LookupFieldRead>[];
    for (final path in _candidatePaths(field, name)) {
      final resolved = await _resolvedUnit(path);
      if (resolved == null) continue;
      final uses = _FieldUseVisitor(field, resolved);
      resolved.unit.accept(uses);
      final noContext = uses.readsWithoutContext;
      if (noContext.isNotEmpty) {
        throw StateError(
          '$name is read without a BuildContext at '
          '${p.basename(path)}:${noContext.first}',
        );
      }
      final assigned = uses.assignments;
      if (assigned.isNotEmpty) {
        throw StateError(
          '$name is assigned at ${p.basename(path)}:${assigned.first}',
        );
      }
      arguments.addAll(uses.arguments);
      reads.addAll(uses.reads);
    }
    return LookupField(
      className: field.enclosingElement.name ?? '',
      name: name,
      path: declarationPath,
      typeOffset: type.offset,
      typeLength: type.length,
      arguments: arguments,
      reads: reads,
    );
  }

  /// The argument expression starting at [offset] of [unit], looking
  /// through parentheses; throws when there is none.
  static Expression _argumentAt(CompilationUnit unit, int offset) {
    Expression? found;
    void visit(AstNode node) {
      if (found != null || node.end <= offset || node.offset > offset) return;
      if (node is Expression &&
          node.offset == offset &&
          (node.parent is ArgumentList || node.parent is NamedArgument)) {
        found = node;
        return;
      }
      node.childEntities.whereType<AstNode>().forEach(visit);
    }

    visit(unit);
    return found ?? (throw StateError('it is not passed as an argument'));
  }

  /// The field [argument] fills through a `this.` parameter, following
  /// `super.` parameters; null when it fills none.
  static FieldElement? _fieldFilledBy(Expression argument) {
    final parent = argument.parent;
    FormalParameterElement? parameter = parent is NamedArgument
        ? parent.correspondingParameter
        : argument.correspondingParameter;
    while (parameter is SuperFormalParameterElement) {
      parameter = parameter.superConstructorParameter;
    }
    return parameter is FieldFormalParameterElement ? parameter.field : null;
  }
}

/// Finds in one resolved unit the values passed to a field through its
/// `this.` (or `super.`) parameters, its reads with the `BuildContext` in
/// scope there, and the reads and writes that rule out a lookup.
class _FieldUseVisitor extends RecursiveAstVisitor<void> {
  _FieldUseVisitor(this._field, this._unit);

  /// Values passed to the field.
  final List<LookupFieldArgument> arguments = [];

  /// 1-based lines where the field is assigned.
  final List<int> assignments = [];

  /// Reads of the field with a `BuildContext` in scope.
  final List<LookupFieldRead> reads = [];

  /// 1-based lines where the field is read without a `BuildContext`.
  final List<int> readsWithoutContext = [];

  final FieldElement _field;

  final ResolvedUnitResult _unit;

  /// The `String` type annotation of [field]'s declaration in [unit]; null
  /// when it has none.
  static TypeAnnotation? typeOf(CompilationUnit unit, FieldElement field) {
    TypeAnnotation? found;
    void visit(AstNode node) {
      if (found != null) return;
      if (node is VariableDeclaration &&
          _UsageVisitor._same(node.declaredFragment!.element, field)) {
        found = (node.parent as VariableDeclarationList?)?.type;
        return;
      }
      node.childEntities.whereType<AstNode>().forEach(visit);
    }

    visit(unit);
    return found;
  }

  @override
  void visitArgumentList(ArgumentList node) {
    for (final argument in node.arguments) {
      final expression = argument is NamedArgument
          ? argument.argumentExpression
          : argument as Expression;
      if (_isField(_LookupFields._fieldFilledBy(expression))) {
        arguments.add((
          path: _unit.path,
          offset: expression.offset,
          length: expression.length,
          source: expression.toSource(),
        ));
      }
    }
    super.visitArgumentList(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is PropertyAccessorElement && _isField(element.variable)) {
      final line = _unit.lineInfo.getLocation(node.offset).lineNumber;
      if (element is SetterElement) {
        assignments.add(line);
      } else {
        final contextName = _contextNameAt(node);
        if (contextName == null) {
          readsWithoutContext.add(line);
        } else {
          final read = _readOf(node);
          reads.add((
            path: _unit.path,
            offset: read.offset,
            end: read.end,
            contextName: contextName,
          ));
        }
      }
    }
    super.visitSimpleIdentifier(node);
  }

  /// Whether [element] is the field.
  bool _isField(Element? element) =>
      element != null && _UsageVisitor._same(element, _field);

  /// The read [name] belongs to, with its receiver, such as `widget.name`.
  static Expression _readOf(SimpleIdentifier name) => switch (name.parent) {
    PrefixedIdentifier(:final identifier) && final read
        when identical(identifier, name) =>
      read,
    PropertyAccess(:final propertyName) && final read
        when identical(propertyName, name) =>
      read,
    _ => name,
  };

  /// The name of a `BuildContext` usable at [node]: the nearest parameter
  /// typed `BuildContext`, or `context` in an instance method of a
  /// `State`; null where there is none, such as in a static factory.
  static String? _contextNameAt(AstNode node) {
    for (
      AstNode? current = node.parent;
      current != null;
      current = current.parent
    ) {
      final FormalParameterList? parameters = switch (current) {
        FunctionExpression(:final parameters) => parameters,
        MethodDeclaration(:final parameters) => parameters,
        ConstructorDeclaration() => null,
        _ => null,
      };
      for (final parameter in parameters?.parameters ?? <FormalParameter>[]) {
        final element = parameter.declaredFragment?.element;
        final name = element?.name;
        if (name != null &&
            name != '_' &&
            element?.type.element?.name == 'BuildContext') {
          return name;
        }
      }
      if (current is ConstructorDeclaration || current is FieldDeclaration) {
        return null;
      }
      if (current is MethodDeclaration) {
        final isStateMember =
            !current.isStatic &&
            !_contextlessStateMethods.contains(current.name.lexeme) &&
            (current
                        .thisOrAncestorOfType<ClassDeclaration>()
                        ?.declaredFragment
                        ?.element
                        .allSupertypes ??
                    const [])
                .any((type) => type.element.name == 'State');
        return isStateMember ? 'context' : null;
      }
    }
    return null;
  }
}
