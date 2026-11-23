part of 'repeated_settings_analyzer.dart';

/// Reads resolved files for the [RepeatedSettingsAnalyzer]: the widgets they build with
/// their styling settings, the numbers in those settings, and the numeric
/// constants the project defines.
class _CallCollector {
  _CallCollector(this.projectPath, {this.views = const {}});

  /// Code standing for state read by a setting, compared by shape only.
  static const String _state = r'$';

  /// Numbers too common to stand for a constant: none, one, minus one.
  static const Set<num> _plainNumbers = {0, 1, -1};

  /// The method returning a widget's content.
  static const String _buildMethod = 'build';

  /// The class every widget extends.
  static const String _widgetClass = 'Widget';

  /// The parameter of a `build` method.
  static const String _contextName = 'context';

  /// The argument a wrapper widget takes its content in.
  static const String _childArgument = 'child';

  /// Types of the settings naming what is shown rather than how.
  static const Set<String> _choiceTypes = {'IconData'};

  /// Layout widgets, and their subclasses, never reported: repeating a
  /// layout is no concern.
  static const Set<String> _layoutWidgets = {
    'Align',
    'AspectRatio',
    'ConstrainedBox',
    'Flex',
    'Flexible',
    'FractionallySizedBox',
    'IndexedStack',
    'IntrinsicHeight',
    'IntrinsicWidth',
    'LimitedBox',
    'Padding',
    'Positioned',
    'ScrollView',
    'SingleChildScrollView',
    'SizedBox',
    'Spacer',
    'Stack',
    'Wrap',
  };

  /// Types a styling setting has, with their subclasses, besides numbers
  /// and enums.
  static const Set<String> _stylingTypes = {
    'AlignmentGeometry',
    'BorderRadiusGeometry',
    'BorderSide',
    'BoxBorder',
    'BoxConstraints',
    'BoxShadow',
    'ButtonStyle',
    'Color',
    'Curve',
    'Decoration',
    'Duration',
    'EdgeInsetsGeometry',
    'Gradient',
    'IconData',
    'InputDecoration',
    'Offset',
    'ShapeBorder',
    'Size',
    'StrutStyle',
    'TextStyle',
    'VisualDensity',
  };

  /// Numeric types a styling setting may have.
  static const Set<String> _numberTypes = {'double', 'int', 'num'};

  /// Whitespace, `const` and trailing commas, which don't change a setting.
  static final RegExp _noise = RegExp(r'\bconst\b|\s+|,(?=\s*[)\]}])');

  /// Root of the project, which locations are relative to.
  final String projectPath;

  /// The project-relative paths of its views, the files declaring a
  /// screen, as [FileLayoutAnalyzer.viewsOf] finds them.
  final Set<String> views;

  /// The widgets built, in file order.
  final List<_WidgetCall> calls = [];

  /// The numeric constants of the project, by value.
  final Map<num, List<_Constant>> constants = {};

  /// Every name a file of the project sees: what a new widget can't be
  /// called.
  final Set<String> takenNames = {};

  /// The libraries whose names [takenNames] holds.
  final Set<LibraryElement> _namedLibraries = {};

  /// The numbers written in styling settings.
  final List<_LiteralUse> literals = [];

  /// Collects what [result] builds and declares.
  void collect(ResolvedUnitResult result) {
    final unit = result.unit;
    final path = ProjectPaths(projectPath).relativeOf(result.path);
    final file = _SourceFile(result);
    for (final library in [
      result.libraryElement,
      for (final import in result.libraryFragment.libraryImports)
        ?import.importedLibrary,
    ]) {
      if (_namedLibraries.add(library)) {
        takenNames.addAll(library.exportNamespace.definedNames2.keys);
      }
    }
    for (final node in _nodesOf(unit)) {
      switch (node) {
        case InstanceCreationExpression():
          _addCall(node, result, path, file);
        case VariableDeclaration(:final isConst, :final initializer?)
            when isConst:
          _addConstant(node, initializer);
      }
    }
  }

  /// Records the widget [node] builds, at [path] in [result], [file],
  /// with its styling settings and the numbers they hold; skips anything
  /// else.
  void _addCall(
    InstanceCreationExpression node,
    ResolvedUnitResult result,
    String path,
    _SourceFile file,
  ) {
    final type = node.staticType;
    if (type is! InterfaceType || !_isWidget(type) || _isLayout(type)) return;
    final location = RepeatedSettingsLocation(
      path,
      result.lineInfo.getLocation(node.offset).lineNumber,
      className: node
          .thisOrAncestorOfType<ClassDeclaration>()
          ?.namePart
          .typeName
          .lexeme,
      isInView: views.contains(path),
    );
    final settings = <String, String>{};
    final sources = <String, String>{};
    final choices = <String>{};
    final arguments = <_Argument>[];
    var position = 0;
    for (final argument in node.argumentList.arguments) {
      final name = argument is NamedArgument
          ? argument.name.lexeme
          : '${RepeatedSettingsFinding.positionalPrefix}${position++}';
      final value = argument.argumentExpression;
      arguments.add(
        _Argument(
          name,
          result.content.substring(value.offset, value.end),
          field: _fieldRead(value),
          parameter: argument.correspondingParameter,
          imported: [
            for (final reference in DartReferenceCollector.collect(value))
              if (reference.needsImport) reference.top,
          ],
          isMovable: _isMovable(value),
        ),
      );
      final parameterType = argument.correspondingParameter?.type;
      if (parameterType == null || !_isStyling(parameterType)) continue;
      final expression = argument.argumentExpression;
      final normalized = _normalized(expression, result.content);
      // Passing state through decides nothing here
      if (normalized == _state) continue;
      settings[name] = normalized;
      if (argument is! NamedArgument ||
          parameterType is InterfaceType && _isA(parameterType, _choiceTypes)) {
        choices.add(name);
      }
      sources[name] = _collapsed(expression.toSource());
      _addLiterals(
        expression,
        location,
        file.scope,
        '${type.element.name} $name',
      );
    }
    final wrappers = _wrappersOf(node);
    final buildClass = node
        .thisOrAncestorOfType<ClassDeclaration>()
        ?.declaredFragment
        ?.element;
    calls.add(
      _WidgetCall(
        widget: node.constructorName.toSource().replaceAll(_noise, ''),
        location: location,
        settings: settings,
        sources: sources,
        choices: choices,
        isProjectWidget: p.isWithin(
          projectPath,
          type.element.library.firstFragment.source.fullName,
        ),
        arguments: arguments,
        offset: node.offset,
        source: result.content.substring(node.offset, node.end),
        isConst: node.keyword?.keyword == Keyword.CONST,
        mustBeConst: node.inConstantContext,
        file: file,
        element: type.element,
        fitsWidget: _fitsWidget(node, result.typeSystem, file),
        isPlain:
            node.constructorName.type.importPrefix == null &&
            node.constructorName.type.typeArguments == null,
        shared:
            wrappers != null && location.isSharedWidget && buildClass != null
            ? _SharedWidget.of(buildClass, wrappers)
            : null,
      ),
    );
  }

  /// Whether the slot [node] is written in takes any `Widget`, so another
  /// widget can take its place: a `child`, not a `Scaffold`'s `appBar`,
  /// which takes a `PreferredSizeWidget`; checked with [typeSystem]
  /// against the `Widget` [file] sees.
  static bool _fitsWidget(
    InstanceCreationExpression node,
    TypeSystem typeSystem,
    _SourceFile file,
  ) {
    final widget = file.scope.lookup(_widgetClass).getter;
    if (widget is! InterfaceElement) return false;
    AstNode current = node;
    var parent = current.parent;
    // Through the expressions and collection elements passing it on
    while (parent is ParenthesizedExpression ||
        parent is ConditionalExpression ||
        parent is IfElement ||
        parent is ForElement ||
        (parent is BinaryExpression &&
            parent.operator.type == TokenType.QUESTION_QUESTION)) {
      current = parent!;
      parent = current.parent;
    }
    final slot = switch (parent) {
      NamedArgument(:final correspondingParameter) =>
        correspondingParameter?.type,
      ArgumentList() when current is Expression =>
        current.correspondingParameter?.type,
      ListLiteral(:final staticType) =>
        staticType is InterfaceType && staticType.typeArguments.isNotEmpty
            ? staticType.typeArguments.first
            : null,
      ReturnStatement() || ExpressionFunctionBody() => switch (node
          .thisOrAncestorOfType<FunctionBody>()
          ?.parent) {
        MethodDeclaration(:final declaredFragment) =>
          declaredFragment?.element.returnType,
        FunctionExpression(:final declaredFragment) =>
          declaredFragment?.element.returnType,
        _ => null,
      },
      VariableDeclaration(:final declaredFragment) =>
        declaredFragment?.element.type,
      _ => null,
    };
    return slot != null && typeSystem.isAssignableTo(widget.thisType, slot);
  }

  /// Whether [value] works as written in another widget's `build`: it
  /// reads no state but the `context` of a `build` method, and names no
  /// static member of its own class without the class.
  static bool _isMovable(Expression value) {
    final finder = _StateFinder();
    value.accept(finder);
    return finder.found.every(
          (read) => read is SimpleIdentifier && read.name == _contextName,
        ) &&
        !_nodesOf(value).any(_isBareStaticMember);
  }

  /// Whether [node] names a static member of a class without the class,
  /// as code inside that class may: `defaultSize`, not `Sizes.small`.
  static bool _isBareStaticMember(AstNode node) {
    if (node is! SimpleIdentifier) return false;
    final element = node.element;
    final isStaticMember = switch (element) {
      ExecutableElement(:final isStatic) || FieldElement(:final isStatic) =>
        isStatic && element?.enclosingElement is InstanceElement,
      _ => false,
    };
    return isStaticMember && !_StateFinder.isMemberName(node);
  }

  /// The field of its enclosing class [value] reads, such as `text`;
  /// null when it reads anything else.
  static String? _fieldRead(Expression value) => switch (value) {
    SimpleIdentifier(
      element: PropertyAccessorElement(
        :final isStatic,
        variable: FieldElement(:final name),
      ),
    )
        when !isStatic =>
      name,
    _ => null,
  };

  /// Records the public numeric constant [node] declares as
  /// [initializer], at the top level or static in a class, reusable for
  /// the numbers equal to it.
  void _addConstant(VariableDeclaration node, Expression initializer) {
    final value = _numberOf(initializer);
    final element = node.declaredFragment?.element;
    final library = element?.library;
    final owner = node.thisOrAncestorOfType<ClassDeclaration>();
    final name = node.name.lexeme;
    final ownerName = owner?.namePart.typeName.lexeme;
    final isToken = switch (element) {
      TopLevelVariableElement() => _onlyConstants(node.root),
      FieldElement(:final isStatic, :final enclosingElement) =>
        isStatic &&
            enclosingElement is ClassElement &&
            _onlyConstants(enclosingElement),
      _ => false,
    };
    // Locals, private constants and those of a widget or other class are
    // no one else's to reuse
    if (value == null ||
        element == null ||
        library == null ||
        !isToken ||
        _plainNumbers.contains(value) ||
        name.startsWith('_') ||
        (ownerName?.startsWith('_') ?? false)) {
      return;
    }
    constants
        .putIfAbsent(value, () => [])
        .add(
          _Constant(
            ownerName == null ? name : '$ownerName.$name',
            ownerName ?? name,
            library.uri.toString(),
            element.type,
          ),
        );
  }

  /// Whether [holder], a class or a file, declares nothing but constants,
  /// as the tokens of a design system do: `AppIconSize`, not a widget's
  /// own constants.
  static bool _onlyConstants(Object holder) => switch (holder) {
    ClassElement(:final fields, :final methods, :final getters) =>
      methods.isEmpty &&
          fields.every((field) => field.isStatic) &&
          getters.every((getter) => getter.isStatic),
    CompilationUnit(:final declarations) => declarations.every(
      (declaration) =>
          declaration is TopLevelVariableDeclaration &&
          declaration.variables.isConst,
    ),
    _ => false,
  };

  /// Records the numbers written in [expression], a setting at
  /// [location] described by [context].
  void _addLiterals(
    Expression expression,
    RepeatedSettingsLocation location,
    Scope scope,
    String context,
  ) {
    for (final node in _nodesOf(expression)) {
      final value = _numberOf(node);
      if (node is Expression &&
          value != null &&
          !_plainNumbers.contains(value)) {
        final named = node.thisOrAncestorOfType<NamedArgument>();
        final setting = named?.name.lexeme ?? '';
        literals.add(
          _LiteralUse(
            value: value,
            source: node.toSource(),
            offset: node.offset,
            type: node.staticType,
            scope: scope,
            location: location,
            // The nearest name says most: `radius` in `circular(radius: 8)`
            context: '$context $setting',
            setting: setting,
          ),
        );
      }
    }
  }

  /// The widgets wrapping [node] in what a `build` method returns, outer
  /// first, [node] being their `child`, such as a `Tooltip`: none when it
  /// is the result itself; null when it isn't in the result.
  static List<String>? _wrappersOf(InstanceCreationExpression node) {
    AstNode current = node;
    final wrappers = <String>[];
    while (true) {
      final parent = current.parent;
      switch (parent) {
        case ReturnStatement() || ExpressionFunctionBody():
          final method = node.thisOrAncestorOfType<MethodDeclaration>();
          return method?.name.lexeme == _buildMethod ? wrappers : null;
        case NamedArgument(:final name) when name.lexeme == _childArgument:
          current = parent.parent!.parent!;
          if (current is! InstanceCreationExpression) return null;
          wrappers.insert(0, current.constructorName.type.name.lexeme);
        default:
          return null;
      }
    }
  }

  /// [expression]'s code with whitespace collapsed.
  static String _collapsed(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

  /// Whether [type] is a styling setting's: a number, an enum, or a
  /// [_stylingTypes] one.
  static bool _isStyling(DartType type) {
    if (type is! InterfaceType) return false;
    final element = type.element;
    return _numberTypes.contains(element.name) ||
        element is EnumElement ||
        _isA(type, _stylingTypes);
  }

  static bool _isLayout(InterfaceType type) => _isA(type, _layoutWidgets);

  static bool _isWidget(InterfaceType type) => _isA(type, const {'Widget'});

  /// Whether [type] or a supertype of it is named in [names].
  static bool _isA(InterfaceType type, Set<String> names) =>
      names.contains(type.element.name) ||
      type.allSupertypes.any(
        (supertype) => names.contains(supertype.element.name),
      );

  /// [expression]'s code with its state reads replaced by [_state] and
  /// what doesn't change it removed.
  static String _normalized(Expression expression, String content) {
    final finder = _StateFinder();
    expression.accept(finder);
    final buffer = StringBuffer();
    var at = expression.offset;
    for (final state in finder.found..sort((a, b) => a.offset - b.offset)) {
      buffer
        ..write(content.substring(at, state.offset))
        ..write(_state);
      at = state.end;
    }
    buffer.write(content.substring(at, expression.end));
    return buffer.toString().replaceAll(_noise, '');
  }

  /// The value of a number literal, negated or not; null for anything
  /// else.
  static num? _numberOf(AstNode node) => switch (node) {
    IntegerLiteral(:final value) => value,
    DoubleLiteral(:final value) => value,
    _ => null,
  };

  /// Every node under [root], [root] included.
  static List<AstNode> _nodesOf(AstNode root) {
    final nodes = <AstNode>[];
    root.accept(_NodeLister(nodes));
    return nodes;
  }
}

/// Lists every node it visits.
class _NodeLister extends GeneralizingAstVisitor<void> {
  _NodeLister(this.nodes);

  final List<AstNode> nodes;

  @override
  void visitNode(AstNode node) {
    nodes.add(node);
    super.visitNode(node);
  }
}
