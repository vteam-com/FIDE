import 'package:fide/models/dart_type_text.dart';
import 'package:fide/models/preview_scan.dart';
import 'package:fide/models/text_case.dart';
import 'package:fide/services/preview_type_resolver.dart';

/// A sample argument: its [code], whether it is a constant, and whether
/// it needs the `const` keyword outside a constant context.
typedef PreviewSample = ({String code, bool isConst, bool needsConst});

/// Builds a widget for a preview with a sample value for each argument its
/// constructor requires, picked from the argument's type alone, without
/// AI: text from its name, the first value of an enum, an empty callback,
/// `Placeholder` for a child widget, and the classes of the project and
/// its packages, built the same way.
///
/// One sampler builds one widget: it gathers the [imports] its samples
/// need and names the type it couldn't build ([missing]).
class PreviewSampler {
  /// Creates the sampler of a widget of the file at [target], resolving
  /// types with [_resolver].
  PreviewSampler(this._resolver, {required this.target});

  /// Deepest a sample nests types, such as a model holding a list of
  /// models.
  static const int _maxDepth = 8;

  /// The library declaring Material's `Colors` and `Icons`.
  static const String _materialImport = 'package:flutter/material.dart';

  static const String _dynamic = 'dynamic';
  static const String _void = 'void';

  /// The type parameter of the callback types of [_callbacks].
  static final RegExp _typeParameter = RegExp(r'\bT\b');

  /// The Flutter callback types, as the function types they name.
  static const Map<String, String> _callbacks = {
    'VoidCallback': 'void Function()',
    'GestureTapCallback': 'void Function()',
    'GestureLongPressCallback': 'void Function()',
    'GestureTapCancelCallback': 'void Function()',
    'AsyncCallback': 'Future<void> Function()',
    'ValueChanged': 'void Function(T value)',
    'ValueSetter': 'void Function(T value)',
    'ValueGetter': 'T Function()',
    'AsyncValueSetter': 'Future<void> Function(T value)',
    'AsyncValueGetter': 'Future<T> Function()',
    'WidgetBuilder': 'Widget Function(BuildContext context)',
    'IndexedWidgetBuilder': 'Widget Function(BuildContext context, int index)',
    'TransitionBuilder':
        'Widget Function(BuildContext context, Widget? child)',
  };

  static const PreviewSample _null = (
    code: 'null',
    isConst: true,
    needsConst: false,
  );

  final PreviewTypeResolver _resolver;

  /// The file the samples are written in.
  final String target;

  /// The URIs of the libraries the samples use that [target] doesn't
  /// import.
  final Set<String> imports = {};

  /// The first type no sample could be picked for; null while every one
  /// could.
  String? missing;

  /// The classes being built, to stop at a class requiring itself.
  final Set<String> _building = {};

  /// The call building [widget], a class of [target], with a sample for
  /// each argument it requires; null when one of them can't be picked.
  String? build(PreviewClass widget) {
    final sample = _construct(widget, (
      name: widget.name,
      path: target,
      scan: _resolver.scanOf(target),
      library: target,
      import: target,
    ), depth: 0);
    return sample == null ? null : _withConst(sample);
  }

  /// The call building [type], declared as [symbol], with a sample for
  /// each argument it requires; null when one of them can't be picked.
  PreviewSample? _construct(
    PreviewClass type,
    PreviewSymbol symbol, {
    required int depth,
  }) {
    final key = '${symbol.path}#${type.name}';
    if (!_building.add(key)) return _miss(type.name);
    try {
      final positional = <PreviewSample>[];
      final named = <(String, PreviewSample)>[];
      for (final parameter in type.requiredParameters) {
        final parameterType = parameter.type;
        final sample = parameterType == null
            ? _miss(parameter.name)
            : _sample(
                parameterType,
                name: parameter.name,
                library: symbol.library,
                depth: depth + 1,
              );
        if (sample == null) return null;
        if (parameter.isNamed) {
          named.add((parameter.name, sample));
        } else {
          positional.add(sample);
        }
      }
      if (!_use(symbol)) return null;
      final isConst =
          type.isConstConstructor &&
          [...positional, for (final (_, sample) in named) sample].every(
            (sample) => sample.isConst,
          );
      final arguments = [
        for (final sample in positional) _inside(sample, isConst: isConst),
        for (final (name, sample) in named)
          '$name: ${_inside(sample, isConst: isConst)}',
      ].join(', ');
      return (
        code: '${type.constructorCall}($arguments)',
        isConst: isConst,
        needsConst: isConst,
      );
    } finally {
      _building.remove(key);
    }
  }

  /// A sample of the type written [text] in the library at [library], for
  /// the parameter [name]; null when none can be picked.
  PreviewSample? _sample(
    String text, {
    required String name,
    required String library,
    required int depth,
  }) {
    if (depth > _maxDepth) return _miss(text);
    final type = DartTypeText.parse(text);
    if (type.isNullable) return _null;
    if (type.isFunction) {
      return _callback(type, name: name, library: library, depth: depth);
    }
    final symbol = _resolver.resolve(
      type.name,
      library: library,
      prefix: type.prefix,
    );
    if (symbol != null) return _declared(symbol, name: name, depth: depth);
    final callback = _callbacks[type.name];
    if (callback != null) {
      final argument = type.arguments.firstOrNull ?? _dynamic;
      return _sample(
        callback.replaceAll(_typeParameter, argument),
        name: name,
        library: library,
        depth: depth + 1,
      );
    }
    return _builtIn(type, name: name, library: library, depth: depth) ??
        _miss(text);
  }

  /// A sample of the type [symbol]: an enum's first value, a sample of the
  /// type an alias names, or a class built with samples.
  PreviewSample? _declared(
    PreviewSymbol symbol, {
    required String name,
    required int depth,
  }) {
    final scan = symbol.scan;
    final value = scan.enumFirstValues[symbol.name];
    if (value != null) return _use(symbol) ? _constant(value) : null;
    final alias = scan.typedefs[symbol.name];
    if (alias != null) {
      return _sample(
        alias,
        name: name,
        library: symbol.library,
        depth: depth + 1,
      );
    }
    final type = scan.classNamed(symbol.name);
    if (type != null && type.isConstructible) {
      return _construct(type, symbol, depth: depth);
    }
    // An abstract class: one of the project's that code can build
    final implementation = _resolver.implementationOf(symbol.name);
    final built = implementation?.scan.classNamed(implementation.name);
    if (implementation == null || built == null) return _miss(symbol.name);
    return _construct(built, implementation, depth: depth);
  }

  /// A sample of a type of the SDK; null for one it has none for.
  PreviewSample? _builtIn(
    DartTypeText type, {
    required String name,
    required String library,
    required int depth,
  }) {
    PreviewSample? wrap(String call, {bool isConstConstructor = false}) =>
        _wrapping(
          call,
          type,
          isConstConstructor: isConstConstructor,
          name: name,
          library: library,
          depth: depth,
        );
    PreviewSample collection(String open, String close) => _collection(
      open,
      close,
      type,
      name: name,
      library: library,
      depth: depth,
    );
    return switch (type.name) {
      'String' => _constant("'${_words(name)}'"),
      'int' || 'num' => _constant('1'),
      'double' => _constant('1.0'),
      'bool' => _constant('true'),
      _dynamic || _void => _null,
      'Object' => _constructed('Object()'),
      DartTypeText.function => _value('() {}'),
      'Widget' => _constructed('Placeholder()'),
      'List' || 'Iterable' => collection('[', ']'),
      'Set' => collection('{', '}'),
      'Map' => _constructed('{}'),
      'Duration' => _constructed('Duration(seconds: 1)'),
      'DateTime' => _value('DateTime.now()'),
      'Uri' => _value("Uri.parse('https://example.com')"),
      'Color' =>
        _sees('Colors')
            ? _constant('Colors.blue')
            : _constructed('Color(0xFF2196F3)'),
      'IconData' => _withMaterial('Icons', _constant('Icons.star')),
      'EdgeInsets' || 'EdgeInsetsGeometry' => _constant('EdgeInsets.zero'),
      'Alignment' || 'AlignmentGeometry' => _constant('Alignment.center'),
      'BorderRadius' ||
      'BorderRadiusGeometry' => _constant('BorderRadius.zero'),
      'Offset' => _constant('Offset.zero'),
      'Size' => _constructed('Size(100, 100)'),
      'TextStyle' => _constructed('TextStyle()'),
      'Listenable' || 'ChangeNotifier' => _value('ChangeNotifier()'),
      'TextEditingController' ||
      'ScrollController' ||
      'PageController' ||
      'FocusNode' => _value('${type.name}()'),
      'Stream' => _constructed('Stream.empty()'),
      'Future' => wrap('Future.value'),
      'FutureOr' => _sample(
        type.arguments.firstOrNull ?? _dynamic,
        name: name,
        library: library,
        depth: depth + 1,
      ),
      'ValueNotifier' || 'ValueListenable' => wrap('ValueNotifier'),
      'Animation' => wrap('AlwaysStoppedAnimation', isConstConstructor: true),
      _ => null,
    };
  }

  /// A callback of the function [type]: empty when it returns nothing,
  /// else returning a sample.
  PreviewSample? _callback(
    DartTypeText type, {
    required String name,
    required String library,
    required int depth,
  }) {
    final parameters = [
      for (var i = 1; i <= type.parameterCount; i++) '_' * i,
    ].join(', ');
    final returned = type.returnType ?? '';
    final result = DartTypeText.parse(returned);
    if (_returnsNothing(result)) return _value('($parameters) {}');
    final awaited = result.arguments.firstOrNull;
    if (result.name == 'Future' &&
        (awaited == null || _returnsNothing(DartTypeText.parse(awaited)))) {
      return _value('($parameters) async {}');
    }
    final value = _sample(
      returned,
      name: name,
      library: library,
      depth: depth + 1,
    );
    if (value == null) return null;
    return _value('($parameters) => ${_withConst(value)}');
  }

  /// A list or set of the collection [type]: one sample of its element
  /// type when it has one, else empty.
  PreviewSample _collection(
    String open,
    String close,
    DartTypeText type, {
    required String name,
    required String library,
    required int depth,
  }) {
    final element = type.arguments.firstOrNull;
    final missed = missing;
    final imported = {...imports};
    final sample = element == null
        ? null
        : _sample(element, name: name, library: library, depth: depth + 1);
    if (sample == null) {
      // An empty collection needs no element: forget the attempt
      missing = missed;
      imports
        ..clear()
        ..addAll(imported);
      return _constructed('$open$close');
    }
    final isConst = sample.isConst;
    return (
      code: '$open${_inside(sample, isConst: isConst)}$close',
      isConst: isConst,
      needsConst: isConst,
    );
  }

  /// A call of [call] with a sample of [type]'s type argument, such as
  /// `ValueNotifier(1)` for `ValueNotifier<int>`.
  PreviewSample? _wrapping(
    String call,
    DartTypeText type, {
    required bool isConstConstructor,
    required String name,
    required String library,
    required int depth,
  }) {
    final sample = _sample(
      type.arguments.firstOrNull ?? _dynamic,
      name: name,
      library: library,
      depth: depth + 1,
    );
    if (sample == null) return null;
    final isConst = isConstConstructor && sample.isConst;
    return (
      code: '$call(${_inside(sample, isConst: isConst)})',
      isConst: isConst,
      needsConst: isConst,
    );
  }

  /// Whether [target]'s code can name [symbol]: it sees it, or importing
  /// the library declaring it adds it without clashing with another type
  /// of its name.
  bool _use(PreviewSymbol symbol) {
    final seen = _resolver.resolve(symbol.name, library: target);
    if (seen == null) {
      imports.add(_resolver.importUri(symbol.import, from: target));
      return true;
    }
    if (seen.path == symbol.path) return true;
    _miss(symbol.name);
    return false;
  }

  /// Whether [target] sees Material's class [name], from Flutter or a
  /// package declaring it.
  bool _sees(String name) =>
      _resolver.importsSdk(target, _materialImport) ||
      _resolver.resolve(name, library: target) != null;

  /// [sample], which uses Material's class [name], importing Material
  /// when [target] doesn't see it.
  PreviewSample _withMaterial(String name, PreviewSample sample) {
    if (!_sees(name)) imports.add(_materialImport);
    return sample;
  }

  /// Records [type] as the one no sample could be picked for, unless an
  /// earlier one was; returns null, for the sample.
  PreviewSample? _miss(String type) {
    missing ??= type;
    return null;
  }

  /// Whether a function returning [type] returns nothing.
  static bool _returnsNothing(DartTypeText type) =>
      type.name.isEmpty || type.name == _void || type.name == _dynamic;

  /// [sample]'s code, with `const` when it needs it.
  static String _withConst(PreviewSample sample) =>
      sample.needsConst ? 'const ${sample.code}' : sample.code;

  /// [sample]'s code as an argument of a call that [isConst] or not.
  static String _inside(PreviewSample sample, {required bool isConst}) =>
      isConst ? sample.code : _withConst(sample);

  /// [name], such as `subtitleText`, as words: `Subtitle text`.
  static String _words(String name) {
    final words = name
        .replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')
        .trim();
    return words.isEmpty ? name : words.capitalized;
  }

  static PreviewSample _constant(String code) =>
      (code: code, isConst: true, needsConst: false);

  static PreviewSample _constructed(String code) =>
      (code: code, isConst: true, needsConst: true);

  static PreviewSample _value(String code) =>
      (code: code, isConst: false, needsConst: false);
}
