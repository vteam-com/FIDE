import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/preview_scan.dart';
import 'package:fide/services/preview_scanner.dart';

/// A sample argument for a widget parameter: its [code], whether it is a
/// constant, and whether it needs the `const` keyword outside a constant
/// context.
typedef PreviewSample = ({String code, bool isConst, bool needsConst});

/// What [PreviewGenerator.generate] did: the file's new content, the
/// preview functions it added, and the widgets it couldn't preview, whose
/// parameters need sample values only someone who knows the code can
/// pick.
typedef PreviewGeneration = ({
  String content,
  List<String> added,
  List<PreviewWidget> skipped,
});

/// Writes a `@Preview` function for each widget of a file that has none,
/// picking each required argument's sample value from its type, without
/// AI: text from the parameter's name, the first value of an enum of the
/// file, an empty callback, `Placeholder` for a child widget...
class PreviewGenerator {
  /// Creates the generator.
  const PreviewGenerator();

  /// The library declaring `Preview`.
  static const String previewImport = 'package:flutter/widget_previews.dart';

  /// The library declaring `Colors` and `Icons`.
  static const String _materialImport = 'package:flutter/material.dart';

  /// The number appended to a preview name already taken, as in
  /// `myWidgetPreview2`.
  static const int _firstNameSuffix = 2;

  static const PreviewSample _null = (
    code: 'null',
    isConst: true,
    needsConst: false,
  );

  /// Matches a function type returning nothing, such as
  /// `void Function(int value)`, its parameters in group 1.
  static final RegExp _functionType = RegExp(
    r'^(?:void\s+)?Function\((.*)\)$',
    dotAll: true,
  );

  /// Callback types taking no argument.
  static const Set<String> _voidCallbacks = {
    'VoidCallback',
    'GestureTapCallback',
    'GestureLongPressCallback',
    'GestureTapCancelCallback',
  };

  /// Callback types taking one argument.
  static const Set<String> _valueCallbacks = {'ValueChanged', 'ValueSetter'};

  /// Adds the previews to [content], scanned as [scan].
  PreviewGeneration generate(String content, PreviewScan scan) {
    final names = {...scan.topLevelNames};
    final hasMaterial = _hasMaterial(scan);
    final functions = <String>[];
    final added = <String>[];
    final skipped = <PreviewWidget>[];
    for (final widget in scan.widgetsWithoutPreview) {
      final call = _call(widget, scan, hasMaterial);
      if (call == null) {
        skipped.add(widget);
        continue;
      }
      final name = _uniqueName(widget.name, names);
      names.add(name);
      added.add(name);
      functions.add(
        '/// A preview of [${widget.name}].\n'
        "@Preview(name: '${widget.name}')\n"
        'Widget $name() => $call;\n',
      );
    }
    if (functions.isEmpty) {
      return (content: content, added: added, skipped: skipped);
    }
    final withPreviews = '${content.trimRight()}\n\n${functions.join('\n')}';
    return (
      content: withImport(
        withPreviews,
        previewImport,
        isImported: (uri) => uri == previewImport,
      ),
      added: added,
      skipped: skipped,
    );
  }

  /// The widgets of [scan] without a preview whose required arguments
  /// [generate] can't pick.
  List<PreviewWidget> skippedIn(PreviewScan scan) {
    final hasMaterial = _hasMaterial(scan);
    return [
      for (final widget in scan.widgetsWithoutPreview)
        if (_call(widget, scan, hasMaterial) == null) widget,
    ];
  }

  /// The call building [widget] with a sample for each required argument,
  /// or null when one of them can't be picked from its type.
  String? _call(PreviewWidget widget, PreviewScan scan, bool hasMaterial) {
    final positional = <PreviewSample>[];
    final named = <(String, PreviewSample)>[];
    for (final parameter in widget.requiredParameters) {
      final sample = _sample(parameter, scan, hasMaterial);
      if (sample == null) return null;
      if (parameter.isNamed) {
        named.add((parameter.name, sample));
      } else {
        positional.add(sample);
      }
    }
    final samples = [...positional, for (final (_, s) in named) s];
    final isConst =
        widget.isConstConstructor && samples.every((s) => s.isConst);
    String code(PreviewSample sample) =>
        !isConst && sample.needsConst ? 'const ${sample.code}' : sample.code;
    final arguments = [
      ...positional.map(code),
      for (final (name, sample) in named) '$name: ${code(sample)}',
    ].join(', ');
    return '${isConst ? 'const ' : ''}${widget.constructorCall}($arguments)';
  }

  /// A sample value for [parameter], or null when its type gives none.
  PreviewSample? _sample(
    PreviewParameter parameter,
    PreviewScan scan,
    bool hasMaterial,
  ) {
    final type = parameter.type;
    if (type == null) return null;
    if (parameter.isNullable) return _null;
    final base = type.split('<').first.trim();
    final enumValue = scan.enumFirstValues[base];
    if (enumValue != null) return _constant(enumValue);
    final function = _functionType.firstMatch(type);
    if (function != null) {
      return _callback(_parameterCount(function.group(1) ?? ''));
    }
    return switch (base) {
      'String' => _constant("'${_words(parameter.name)}'"),
      'int' || 'num' => _constant('1'),
      'double' => _constant('1.0'),
      'bool' => _constant('true'),
      'Widget' => _constructed('Placeholder()'),
      'List' || 'Iterable' => _constructed('[]'),
      'Map' || 'Set' => _constructed('{}'),
      'Duration' => _constructed('Duration(seconds: 1)'),
      'DateTime' => (code: 'DateTime.now()', isConst: false, needsConst: false),
      'Color' =>
        hasMaterial
            ? _constant('Colors.blue')
            : _constructed('Color(0xFF2196F3)'),
      'IconData' => hasMaterial ? _constant('Icons.star') : null,
      'AsyncCallback' => (
        code: '() async {}',
        isConst: false,
        needsConst: false,
      ),
      _ when _voidCallbacks.contains(base) => _callback(0),
      _ when _valueCallbacks.contains(base) => _callback(1),
      _ => null,
    };
  }

  /// Whether [scan]'s file imports Material, so samples can use `Colors`
  /// and `Icons`.
  static bool _hasMaterial(PreviewScan scan) =>
      scan.imports.any((i) => i.uri == _materialImport);

  /// A preview function name for [className] not in [taken], such as
  /// `myWidgetPreview`.
  static String _uniqueName(String className, Set<String> taken) {
    final base =
        '${className[0].toLowerCase()}${className.substring(1)}'
        '${PreviewScanner.previewClass}';
    var name = base;
    for (var suffix = _firstNameSuffix; taken.contains(name); suffix++) {
      name = '$base$suffix';
    }
    return name;
  }

  /// [name], such as `subtitleText`, as words: `Subtitle text`.
  static String _words(String name) {
    final words = name
        .replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')
        .trim();
    return words.isEmpty
        ? name
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  /// How many parameters [list], the inside of a function type's
  /// parentheses, declares.
  static int _parameterCount(String list) {
    final text = list.trim().replaceAll(RegExp(r'[{}\[\]]'), '');
    if (text.isEmpty) return 0;
    var depth = 0;
    var count = 1;
    for (final char in text.split('')) {
      if (char == '<' || char == '(') depth++;
      if (char == '>' || char == ')') depth--;
      if (char == ',' && depth == 0) count++;
    }
    return text.trimRight().endsWith(',') ? count - 1 : count;
  }

  /// An empty callback taking [count] arguments, such as `(_, __) {}`.
  static PreviewSample _callback(int count) {
    final parameters = [for (var i = 1; i <= count; i++) '_' * i].join(', ');
    return (code: '($parameters) {}', isConst: false, needsConst: false);
  }

  static PreviewSample _constant(String code) =>
      (code: code, isConst: true, needsConst: false);

  static PreviewSample _constructed(String code) =>
      (code: code, isConst: true, needsConst: true);
}
