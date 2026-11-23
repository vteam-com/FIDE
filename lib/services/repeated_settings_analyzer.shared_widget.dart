part of 'repeated_settings_analyzer.dart';

/// A parameter of a shared widget's constructor: its [name], the [field]
/// it initializes (`this.text`), its [position] when positional, whether
/// a call must pass it and whether it has a default value.
typedef _Parameter = ({
  String name,
  String? field,
  int? position,
  bool isRequired,
  bool hasDefault,
});

/// A project widget under `lib/widgets/` whose `build` returns the
/// widget a clone repeats, such as a `TruncatedText` returning
/// `Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)`: the clone
/// can be rewritten as a call to it.
class _SharedWidget {
  _SharedWidget(
    this.name,
    this.libraryUri,
    this.parameters, {
    required this.isConst,
    required this.wrappers,
  });

  /// Name of the parameter every widget takes its key in.
  static const String _keyParameter = 'key';

  /// Whether its unnamed constructor is `const`.
  final bool isConst;

  /// The library declaring it, imported where it is used.
  final String libraryUri;

  /// Its class name.
  final String name;

  /// Its unnamed constructor's parameters.
  final List<_Parameter> parameters;

  /// The widgets its `build` wraps the repeated one in, outer first, such
  /// as a `Tooltip`: what using it adds.
  final List<String> wrappers;

  /// What the fix using it says: `Use TruncatedText`.
  String get label => 'Use $name';

  /// What using it adds around the repeated widget, for the suggestion:
  /// `, which adds its Tooltip`; empty when it adds nothing.
  String get addition =>
      wrappers.isEmpty ? '' : ', which adds its ${wrappers.join(', ')}';

  /// The shared widget [element] declares, its `build` returning the
  /// repeated widget inside [wrappers], when its unnamed constructor's
  /// parameters can be mapped; null for a generic or abstract class, or
  /// one without an unnamed constructor.
  static _SharedWidget? of(ClassElement element, List<String> wrappers) {
    final constructor = element.unnamedConstructor;
    if (constructor == null ||
        element.isAbstract ||
        element.typeParameters.isNotEmpty) {
      return null;
    }
    var position = 0;
    final parameters = <_Parameter>[
      for (final parameter in constructor.formalParameters)
        (
          name: parameter.name ?? '',
          field: parameter is FieldFormalParameterElement
              ? parameter.field?.name
              : null,
          position: parameter.isPositional ? position++ : null,
          isRequired: parameter.isRequired,
          hasDefault: parameter.hasDefaultValue,
        ),
    ];
    return _SharedWidget(
      element.name ?? '',
      element.library.uri.toString(),
      parameters,
      isConst: constructor.isConst,
      wrappers: wrappers,
    );
  }

  /// The edit rewriting [call], a clone of [built] (the widget this one's
  /// `build` returns), as a call to this widget: the settings [built]
  /// fixes dropped, each other argument passed to the parameter whose
  /// field [built] reads in its place. Null when an argument has no such
  /// parameter, a required parameter would go unset, a parameter with a
  /// default would replace the widget's own, [call]'s slot takes only its
  /// own kind of widget, or [call] must be constant and this widget can't.
  RepeatedSettingsEdit? rewrite(_WidgetCall call, _WidgetCall built) {
    if (!call.fitsWidget || (call.mustBeConst && !isConst)) return null;
    final positional = <int, String>{};
    final named = <String, String>{};
    final passed = <_Parameter>{};
    for (final argument in call.arguments) {
      if (built.settings.containsKey(argument.name)) continue;
      final parameter = argument.name == _keyParameter
          ? _parameterNamed(_keyParameter)
          : _parameterOf(built.argumentNamed(argument.name)?.field);
      if (parameter == null) return null;
      passed.add(parameter);
      if (parameter.position case final position?) {
        positional[position] = argument.source;
      } else {
        named[parameter.name] = argument.source;
      }
    }
    final unset = {
      for (final parameter in parameters)
        if (!passed.contains(parameter)) parameter,
    };
    // An unset parameter [built] reads must leave the widget's own default
    final defaultsRead = built.arguments.any((argument) {
      final read = _parameterOf(argument.field);
      return read != null && unset.contains(read) && read.hasDefault;
    });
    if (unset.any((parameter) => parameter.isRequired) ||
        defaultsRead ||
        positional.keys.any((position) => position >= positional.length)) {
      return null;
    }
    final arguments = [
      for (var position = 0; position < positional.length; position++)
        positional[position]!,
      for (final MapEntry(:key, :value) in named.entries) '$key: $value',
    ];
    return RepeatedSettingsEdit(
      call.location.path,
      call.offset,
      call.source,
      '${call.isConst ? 'const ' : ''}$name(${arguments.join(', ')})',
      importUri: call.file.scope.lookup(name).getter == null
          ? libraryUri
          : null,
    );
  }

  /// The parameter initializing [field]; null for none.
  _Parameter? _parameterOf(String? field) => field == null
      ? null
      : parameters.where((parameter) => parameter.field == field).firstOrNull;

  /// The parameter called [name]; null for none.
  _Parameter? _parameterNamed(String name) =>
      parameters.where((parameter) => parameter.name == name).firstOrNull;
}
