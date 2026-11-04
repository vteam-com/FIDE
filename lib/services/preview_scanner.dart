import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:fide/models/preview_scan.dart';

/// Finds the widget previews, widgets and imports of a Dart file from its
/// syntax alone, so it works on any file, even one that doesn't compile.
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

  /// Scans Dart [content]; [PreviewScan.empty] when it can't be parsed.
  PreviewScan scan(String content) {
    final CompilationUnit unit;
    try {
      unit = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
    } on Object {
      return PreviewScan.empty;
    }
    final lines = unit.lineInfo;
    final previews = <PreviewDeclaration>[];
    final widgets = <PreviewWidget>[];
    final enums = <String, String>{};
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
          final widget = _widget(name, member, lines);
          if (widget != null) widgets.add(widget);
        case EnumDeclaration():
          final name = member.namePart.typeName.lexeme;
          names.add(name);
          final first = member.body.constants.firstOrNull;
          if (first != null) enums[name] = '$name.${first.name.lexeme}';
        case TopLevelVariableDeclaration():
          names.addAll(member.variables.variables.map((v) => v.name.lexeme));
        default:
      }
    }
    return PreviewScan(
      previews: previews,
      widgets: widgets,
      imports: [
        for (final directive in unit.directives)
          if (directive is ImportDirective) _import(content, directive),
      ],
      enumFirstValues: enums,
      topLevelNames: names,
      isPart: unit.directives.any((d) => d is PartOfDirective),
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

  /// [node] as a widget class with the constructor a preview would call,
  /// or null when it isn't a concrete widget.
  PreviewWidget? _widget(String name, ClassDeclaration node, LineInfo lines) {
    final superclass = node.extendsClause?.superclass.name.lexeme;
    if (superclass == null ||
        !superclass.endsWith(_widgetSuffix) ||
        node.abstractKeyword != null) {
      return null;
    }
    final constructors = node.body.members
        .whereType<ConstructorDeclaration>()
        .where((c) => !_isPrivate(c.name?.lexeme ?? ''))
        .toList();
    final constructor =
        constructors.where((c) => c.name == null).firstOrNull ??
        constructors.firstOrNull;
    if (constructor == null && node.body.members.any(_isConstructor)) {
      // Only private constructors: no preview can build it
      return null;
    }
    return PreviewWidget(
      name: name,
      line: lines.getLocation(node.offset).lineNumber,
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

  /// [directive] of [content] with the offsets of its URIs in its source.
  PreviewImport _import(String content, ImportDirective directive) {
    final start = directive.offset;
    final literals = [
      directive.uri,
      for (final configuration in directive.configurations) configuration.uri,
    ];
    return PreviewImport(
      source: content.substring(start, directive.end),
      uris: [
        for (final literal in literals)
          if (literal.stringValue case final uri?)
            (start: literal.offset - start, end: literal.end - start, uri: uri),
      ],
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
    final size = arguments.arguments
        .whereType<NamedArgument>()
        .where((argument) => argument.name.lexeme == sizeArgument)
        .firstOrNull;
    return PreviewAnnotation(
      constant,
      argumentsStart: arguments.leftParenthesis.end,
      argumentsEnd: arguments.rightParenthesis.offset,
      sizeArgument: size == null ? null : (start: size.offset, end: size.end),
    );
  }

  /// Whether a call must pass some of [parameters].
  static bool _hasRequired(FormalParameterList? parameters) =>
      parameters?.parameters.any((p) => p.isRequired) ?? false;

  static bool _isConstructor(ClassMember member) =>
      member is ConstructorDeclaration;

  static bool _isPrivate(String name) => name.startsWith('_');
}
