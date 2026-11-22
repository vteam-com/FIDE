import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:fide/models/dart_parse.dart';
import 'package:fide/models/preview_scan.dart';

/// Finds the widget previews, classes, enums, type aliases and directives
/// of a Dart file from its syntax alone, so it works on any file, even one
/// that doesn't compile.
///
/// A preview is a public top-level function, static method or constructor
/// without required parameters, annotated with `Preview`, a subclass whose
/// name ends with `Preview` (such as `BrightnessPreview`) or a
/// `MultiPreview` named that way.
class PreviewScanner {
  /// Creates the scanner.
  const PreviewScanner();

  /// The class of plain preview annotations, and the suffix of the
  /// annotation classes taken for previews.
  static const String previewClass = 'Preview';

  /// The `Preview` argument setting a preview's size.
  static const String sizeArgument = 'size';

  /// Suffix of the superclasses that make a class a widget, such as
  /// `StatelessWidget` or `ConsumerWidget`.
  static const String _widgetSuffix = 'Widget';

  /// The return type of a function type alias that writes none.
  static const String _void = 'void';

  /// Scans Dart [content]; [PreviewScan.empty] when it can't be parsed.
  PreviewScan scan(String content) {
    final CompilationUnit unit;
    try {
      unit = parseDart(content).unit;
    } on Object {
      return PreviewScan.empty;
    }
    final lines = unit.lineInfo;
    final previews = <PreviewDeclaration>[];
    final classes = <PreviewClass>[];
    final enums = <String, String>{};
    final typedefs = <String, String>{};
    final names = <String>{};
    for (final member in unit.declarations) {
      switch (member) {
        case FunctionDeclaration():
          names.add(member.name.lexeme);
          final declaration = _function(member, lines);
          if (declaration != null) previews.add(declaration);
        case ClassDeclaration():
          final name = member.namePart.typeName.lexeme;
          names.add(name);
          if (_isPrivate(name)) continue;
          previews.addAll(_classPreviews(name, member, lines));
          classes.add(_class(name, member, lines));
        case EnumDeclaration():
          final name = member.namePart.typeName.lexeme;
          names.add(name);
          final first = member.body.constants.firstOrNull;
          if (first != null) enums[name] = '$name.${first.name.lexeme}';
        case GenericTypeAlias():
          names.add(member.name.lexeme);
          typedefs[member.name.lexeme] = member.type.toSource();
        case FunctionTypeAlias():
          names.add(member.name.lexeme);
          typedefs[member.name.lexeme] =
              '${member.returnType?.toSource() ?? _void} '
              'Function${member.parameters.toSource()}';
        case TopLevelVariableDeclaration():
          names.addAll(member.variables.variables.map((v) => v.name.lexeme));
        default:
      }
    }
    final directives = unit.directives;
    return PreviewScan(
      previews: previews,
      classes: classes,
      imports: [
        for (final directive in directives.whereType<ImportDirective>())
          _directive(content, directive),
      ],
      exports: [
        for (final directive in directives.whereType<ExportDirective>())
          _directive(content, directive),
      ],
      parts: [
        for (final directive in directives.whereType<PartDirective>())
          ?directive.uri.stringValue,
      ],
      enumFirstValues: enums,
      typedefs: typedefs,
      topLevelNames: names,
      isPart: directives.any((d) => d is PartOfDirective),
    );
  }

  /// The preview a top-level [function] declares, if it is one.
  PreviewDeclaration? _function(FunctionDeclaration function, LineInfo lines) {
    final name = function.name.lexeme;
    final parameters = function.functionExpression.parameters;
    return _declaration(
      metadata: function.metadata,
      label: name,
      invocation: '$name()',
      isCallable:
          !_isPrivate(name) &&
          !function.isGetter &&
          !function.isSetter &&
          function.functionExpression.typeParameters == null &&
          !_hasRequired(parameters),
      node: function,
      lines: lines,
    );
  }

  /// The previews of class [className]'s static methods and constructors.
  List<PreviewDeclaration> _classPreviews(
    String className,
    ClassDeclaration node,
    LineInfo lines,
  ) {
    final previews = <PreviewDeclaration>[];
    for (final member in node.body.members) {
      final PreviewDeclaration? declaration;
      switch (member) {
        case MethodDeclaration(isStatic: true):
          final name = member.name.lexeme;
          declaration = _declaration(
            metadata: member.metadata,
            label: '$className.$name',
            invocation: '$className.$name()',
            isCallable:
                !_isPrivate(name) &&
                !member.isGetter &&
                !member.isSetter &&
                member.typeParameters == null &&
                !_hasRequired(member.parameters),
            node: member,
            lines: lines,
          );
        case ConstructorDeclaration():
          final name = member.name?.lexeme;
          final call = name == null ? className : '$className.$name';
          declaration = _declaration(
            metadata: member.metadata,
            label: call,
            invocation: '$call()',
            isCallable:
                (name == null || !_isPrivate(name)) &&
                node.abstractKeyword == null &&
                !_hasRequired(member.parameters),
            node: member,
            lines: lines,
          );
        default:
          declaration = null;
      }
      if (declaration != null) previews.add(declaration);
    }
    return previews;
  }

  /// The preview [node] declares when it is [isCallable] and annotated
  /// with previews.
  PreviewDeclaration? _declaration({
    required List<Annotation> metadata,
    required String label,
    required String invocation,
    required bool isCallable,
    required AstNode node,
    required LineInfo lines,
  }) {
    final annotations = metadata.where(_isPreview).map(_annotation).toList();
    if (!isCallable || annotations.isEmpty) return null;
    return PreviewDeclaration(
      label: label,
      invocation: invocation,
      annotations: annotations,
      line: lines.getLocation(node.offset).lineNumber,
      source: node.toSource(),
    );
  }

  /// [node] as a class with the constructor code calls to build it: the
  /// unnamed one when public, else the first public one; for an abstract
  /// class, the first public factory.
  PreviewClass _class(String name, ClassDeclaration node, LineInfo lines) {
    final isAbstract =
        node.abstractKeyword != null || node.sealedKeyword != null;
    final superclass = node.extendsClause?.superclass.name.lexeme;
    final constructors = node.body.members
        .whereType<ConstructorDeclaration>()
        .where(
          (c) =>
              !_isPrivate(c.name?.lexeme ?? '') &&
              (!isAbstract || c.factoryKeyword != null),
        )
        .toList();
    final constructor =
        constructors.where((c) => c.name == null).firstOrNull ??
        constructors.firstOrNull;
    return PreviewClass(
      name: name,
      line: lines.getLocation(node.offset).lineNumber,
      isWidget: superclass?.endsWith(_widgetSuffix) ?? false,
      supertypes: [
        ?superclass,
        for (final type in [
          ...?node.implementsClause?.interfaces,
          ...?node.withClause?.mixinTypes,
        ])
          type.name.lexeme,
      ],
      // Without a constructor declared, a concrete class has the default
      isConstructible:
          constructor != null ||
          (!isAbstract && !node.body.members.any(_isConstructor)),
      constructorName: constructor?.name?.lexeme ?? '',
      isConstConstructor: constructor?.constKeyword != null,
      parameters: [
        for (final parameter in constructor?.parameters.parameters ?? [])
          if (parameter.name case final token?)
            PreviewParameter(
              name: token.lexeme,
              type: parameter.type?.toSource() ?? _fieldType(node, parameter),
              isNamed: parameter.isNamed,
              isRequired: parameter.isRequired,
            ),
      ],
    );
  }

  /// The declared type of the field a `this.` [parameter] initializes.
  String? _fieldType(ClassDeclaration node, FormalParameter parameter) {
    if (parameter is! FieldFormalParameter) return null;
    for (final field in node.body.members.whereType<FieldDeclaration>()) {
      final declares = field.fields.variables.any(
        (variable) => variable.name.lexeme == parameter.name.lexeme,
      );
      if (declares) return field.fields.type?.toSource();
    }
    return null;
  }

  /// [directive] of [content] with the offsets of its URIs in its source,
  /// its prefix and the names its `show` and `hide` combinators list.
  PreviewDirective _directive(String content, NamespaceDirective directive) {
    final start = directive.offset;
    final literals = [
      directive.uri,
      for (final configuration in directive.configurations) configuration.uri,
    ];
    final combinators = directive.combinators;
    final shows = combinators.whereType<ShowCombinator>();
    return PreviewDirective(
      source: content.substring(start, directive.end),
      uris: [
        for (final literal in literals)
          if (literal.stringValue case final uri?)
            (start: literal.offset - start, end: literal.end - start, uri: uri),
      ],
      prefix: directive is ImportDirective ? directive.prefix?.name : null,
      shown: shows.isEmpty
          ? null
          : {for (final show in shows) ...show.shownNames.map((n) => n.name)},
      hidden: {
        for (final hide in combinators.whereType<HideCombinator>())
          ...hide.hiddenNames.map((n) => n.name),
      },
    );
  }

  /// Whether [annotation] names a preview class: its class name, the
  /// last part of a prefixed name or the first of a named constructor,
  /// ends with [previewClass].
  static bool _isPreview(Annotation annotation) {
    final name = annotation.name;
    final parts = switch (name) {
      PrefixedIdentifier() => [name.prefix.name, name.identifier.name],
      _ => [name.name],
    };
    return parts.any((part) => part.endsWith(previewClass)) &&
        !annotation.toSource().contains(RegExp(r'\b_'));
  }

  /// [annotation] as a constant expression, such as
  /// `const Preview(name: 'x')`, with the offsets of its arguments when it
  /// is a plain `Preview(...)`.
  static PreviewAnnotation _annotation(Annotation annotation) {
    final expression = annotation.toSource().substring(1);
    final arguments = annotation.arguments;
    if (arguments == null) return PreviewAnnotation(expression);
    final constant = 'const $expression';
    final name = annotation.name;
    final className = name is PrefixedIdentifier
        ? name.identifier.name
        : name.name;
    if (className != previewClass || annotation.constructorName != null) {
      return PreviewAnnotation(constant);
    }
    final all = arguments.arguments;
    final at = all.indexWhere(
      (argument) =>
          argument is NamedArgument && argument.name.lexeme == sizeArgument,
    );
    final size = at < 0 ? null : all[at];
    final start = arguments.leftParenthesis.end;
    final end = arguments.rightParenthesis.offset;
    return PreviewAnnotation(
      constant,
      argumentsStart: start,
      argumentsEnd: end,
      sizeArgument: size == null ? null : (start: size.offset, end: size.end),
      sizeRemoval: size == null
          ? null
          // Up to the next argument, else from the previous one, else all
          : switch ((
              at > 0 ? all[at - 1] : null,
              all.elementAtOrNull(at + 1),
            )) {
              (_, final next?) => (start: size.offset, end: next.offset),
              (final previous?, null) => (start: previous.end, end: size.end),
              (null, null) => (start: start, end: end),
            },
    );
  }

  /// Whether a call must pass some of [parameters].
  static bool _hasRequired(FormalParameterList? parameters) =>
      parameters?.parameters.any((p) => p.isRequired) ?? false;

  static bool _isConstructor(ClassMember member) =>
      member is ConstructorDeclaration;

  static bool _isPrivate(String name) => name.startsWith('_');
}
