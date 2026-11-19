part of 'dry_analyzer.dart';

/// Extracts the widget a group of clones builds alike into a new shared
/// widget under `lib/widgets/`, named by the user: its `build` writes the
/// settings the clones share, and every other argument (the content, or
/// a setting reading the place's own state) becomes a parameter typed as
/// the original widget's.
class _Extraction {
  _Extraction(this._group, this._takenNames);

  /// The prefix of the name proposed when the settings name nothing, or
  /// what they name is taken: `SharedText`.
  static const String _sharedPrefix = 'Shared';

  /// Name of the parameter every widget takes its key in.
  static const String _keyName = 'key';

  /// Names a field of the new widget can't take.
  static const Set<String> _reservedNames = {'build', 'context'};

  /// The framework classes the new widget's code names.
  static const List<String> _frameworkNames = [
    'BuildContext',
    'StatelessWidget',
    'Widget',
  ];

  /// Most setting values the proposed name is made of.
  static const int _maxNameWords = 2;

  /// A setting picking one value of a type: `Alignment.centerRight`.
  static final RegExp _token = RegExp(r'^\w+\.(\w+)$');

  final List<_WidgetCall> _group;

  /// Every name the project sees, which the new widget can't take.
  final Set<String> _takenNames;

  /// The fix extracting [group]'s widget, ready to be named, proposing a
  /// name none of [takenNames]; null when its code can't move as it is,
  /// such as a setting reading a private name, an argument left out
  /// somewhere whose default the new widget would replace, a generic
  /// type, or a slot taking only that kind of widget, such as an `appBar`.
  static DryFix? fixOf(List<_WidgetCall> group, Set<String> takenNames) =>
      _Extraction(group, takenNames)._fix();

  /// [fixOf]'s work: splits the arguments into the settings kept in the
  /// new widget and its parameters, checks every name it needs imports
  /// and every place can call it, then writes its code and the edits.
  DryFix? _fix() {
    final first = _group.first;
    final package = first.file.package;
    if (package == null ||
        _group.any((call) => !call.isPlain || !call.fitsWidget)) {
      return null;
    }
    final fixed = {
      for (final name in first.settings.keys)
        if (_group.every(
          (call) => call.argumentNamed(name)?.isMovable ?? false,
        ))
          name,
    };
    final parameters = <String, FormalParameterElement>{};
    for (final call in _group) {
      for (final argument in call.arguments) {
        if (fixed.contains(argument.name)) continue;
        final parameter = argument.parameter;
        if (parameter == null) return null;
        parameters[argument.name] = parameter;
      }
    }
    final types = <Element>[];
    for (final MapEntry(key: name, value: parameter) in parameters.entries) {
      final everywhere = _group.every(
        (call) => call.argumentNamed(name) != null,
      );
      final elements = _typeElements(parameter.type);
      if ((!everywhere && parameter.hasDefaultValue) ||
          (parameter.isPositional && !parameter.isRequired) ||
          _reservedNames.contains(parameter.name) ||
          elements == null) {
        return null;
      }
      if (name != _keyName) types.addAll(elements);
    }
    final framework = [
      for (final name in _frameworkNames) first.file.scope.lookup(name).getter,
    ];
    final imports = <String>{};
    for (final element in {
      first.element,
      ...framework,
      for (final name in fixed) ...first.argumentNamed(name)!.imported,
      ...types,
    }) {
      final uri = element == null ? null : first.file.importOf(element);
      if (uri == null) return null;
      if (uri.isNotEmpty) imports.add(uri);
    }
    final fields = {
      for (final MapEntry(key: name, value: parameter) in parameters.entries)
        if (name != _keyName) name: parameter,
    };
    final required = {
      for (final name in fields.keys)
        if (_group.every((call) => call.argumentNamed(name) != null)) name,
    };
    final importUri = 'package:$package/${_widgetPath(withLib: false)}';
    return DryFix(
      'Extract widget…',
      [for (final call in _group) _rewrite(call, fields, importUri)],
      created: {
        _widgetPath(withLib: true): _widgetCode(
          fixed,
          fields,
          imports,
          required,
        ),
      },
      nameHint: _nameHint(fixed),
    );
  }

  /// The new widget's file, under `lib` when [withLib], else relative to
  /// it as its `package:` URI is.
  static String _widgetPath({required bool withLib}) =>
      '${withLib ? 'lib/' : ''}widgets/${DryFix.widgetFile}.dart';

  /// The edit writing [call] as a call to the new widget with [fields],
  /// importing it from [importUri].
  DryEdit _rewrite(
    _WidgetCall call,
    Map<String, FormalParameterElement> fields,
    String importUri,
  ) {
    final positional = _positional(fields);
    final arguments = [
      for (final name in positional) call.argumentNamed(name)!.source,
      for (final name in [_keyName, ..._named(fields)])
        if (call.argumentNamed(name) case final argument?)
          '${_fieldName(name, fields)}: ${argument.source}',
    ];
    return DryEdit(
      call.location.path,
      call.offset,
      call.source,
      '${call.isConst ? 'const ' : ''}${DryFix.widgetName}'
      '(${arguments.join(', ')})',
      importUri: importUri,
    );
  }

  /// The new widget's code: [imports], then the class keeping the
  /// [fixed] settings and taking the [fields], the [required] ones (those
  /// every place passes) required.
  String _widgetCode(
    Set<String> fixed,
    Map<String, FormalParameterElement> fields,
    Set<String> imports,
    Set<String> required,
  ) {
    final first = _group.first;
    final widget = first.widget;
    final positional = _positional(fields);
    final named = _named(fields);
    String field(String name) => _fieldName(name, fields);
    final namedParameters = [
      'super.key',
      for (final name in named)
        '${required.contains(name) ? 'required ' : ''}this.${field(name)}',
    ];
    final constructorParameters = [
      for (final name in positional) 'this.${field(name)}',
      '{${namedParameters.join(', ')}}',
    ].join(', ');
    final positionalArguments = {
      ...fixed,
      ...positional,
    }.where(_isPositional).toList()..sort(_byPosition);
    final buildArguments = [
      for (final name in positionalArguments)
        fixed.contains(name) ? first.argumentNamed(name)!.source : field(name),
      for (final name in fixed.where((name) => !_isPositional(name)))
        '$name: ${first.argumentNamed(name)!.source}',
      for (final name in named) '$name: $name',
    ];
    final sortedImports = imports.toList()..sort();
    return [
      for (final uri in sortedImports) "import '$uri';",
      '',
      '/// The [$widget] the project builds alike in several places.',
      'class ${DryFix.widgetName} extends StatelessWidget {',
      '  /// Creates the [$widget].',
      '  const ${DryFix.widgetName}($constructorParameters);',
      for (final name in [...positional, ...named]) ...[
        '',
        "  /// Passed to [$widget]'s `${fields[name]!.name}`.",
        '  final ${fields[name]!.type.getDisplayString()} ${field(name)};',
      ],
      '',
      '  @override',
      '  Widget build(BuildContext context) {',
      '    return $widget(${buildArguments.join(', ')});',
      '  }',
      '}',
      '',
    ].join('\n');
  }

  /// The positional parameters among [fields], in their order.
  static List<String> _positional(Map<String, FormalParameterElement> fields) =>
      fields.keys.where(_isPositional).toList()..sort(_byPosition);

  /// The named parameters among [fields], by name.
  static List<String> _named(Map<String, FormalParameterElement> fields) =>
      fields.keys.where((name) => !_isPositional(name)).toList()..sort();

  /// The field the argument called [name] goes to: the original widget's
  /// parameter name, `data` for the `#0` of a `Text`.
  static String _fieldName(
    String name,
    Map<String, FormalParameterElement> fields,
  ) => _isPositional(name) ? fields[name]!.name ?? name : name;

  static bool _isPositional(String name) =>
      name.startsWith(DryFinding.positionalPrefix);

  /// Orders positional argument names by index.
  static int _byPosition(String a, String b) => _indexOf(a) - _indexOf(b);

  static int _indexOf(String name) =>
      int.parse(name.substring(DryFinding.positionalPrefix.length));

  /// The name proposed for the new widget: the distinct values of up to
  /// [_maxNameWords] of the [fixed] settings, then the widget's,
  /// `CenterRightFitHeightFittedBox`; `SharedText` when they name nothing
  /// or that is taken, numbered when that is taken too.
  String _nameHint(Set<String> fixed) {
    final first = _group.first;
    final widget = first.element.name ?? '';
    final words = {
      for (final name in fixed.toList()..sort())
        if (_token.firstMatch(first.argumentNamed(name)!.source)?[1]
            case final value?)
          value[0].toUpperCase() + value.substring(1),
    }.take(_maxNameWords);
    final named = '${words.join()}$widget';
    if (words.isNotEmpty && !_takenNames.contains(named)) return named;
    return uniqueName('$_sharedPrefix$widget', _takenNames.contains);
  }

  /// The declarations [type] names, to import; null for a type with type
  /// parameters, which the new widget doesn't have.
  static List<Element>? _typeElements(DartType type) {
    final elements = <Element>[];
    bool walk(DartType type) {
      if (type.alias case final alias?) {
        elements.add(alias.element);
        if (!alias.typeArguments.every(walk)) return false;
      }
      if (type is InterfaceType) elements.add(type.element);
      return switch (type) {
        TypeParameterType() => false,
        InterfaceType(:final typeArguments) => typeArguments.every(walk),
        FunctionType(:final returnType, :final formalParameters) =>
          walk(returnType) &&
              formalParameters.every((parameter) => walk(parameter.type)),
        RecordType(:final positionalFields, :final namedFields) =>
          positionalFields.every((field) => walk(field.type)) &&
              namedFields.every((field) => walk(field.type)),
        _ => true,
      };
    }

    return walk(type) ? elements : null;
  }
}
