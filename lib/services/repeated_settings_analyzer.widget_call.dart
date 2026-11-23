part of 'repeated_settings_analyzer.dart';

/// A widget built somewhere: its styling [settings], compared, and the
/// [sources] they are written as, shown.
class _WidgetCall {
  _WidgetCall({
    required this.widget,
    required this.location,
    required this.settings,
    required this.sources,
    required this.isProjectWidget,
    required this.choices,
    required this.arguments,
    required this.offset,
    required this.source,
    required this.isConst,
    required this.mustBeConst,
    required this.file,
    required this.element,
    required this.isPlain,
    required this.fitsWidget,
    this.shared,
  });

  /// Every argument, in order.
  final List<_Argument> arguments;

  /// Whether the call is written `const`.
  final bool isConst;

  /// Whether the call must stay constant: written `const` or in a
  /// constant context, such as a `const` list.
  final bool mustBeConst;

  /// Offset of the call in its file.
  final int offset;

  /// The widget's class.
  final InterfaceElement element;

  /// The file it is built in.
  final _SourceFile file;

  /// Whether the slot it is written in takes any widget, so another
  /// widget can replace it.
  final bool fitsWidget;

  /// Whether the call names the widget plainly, without an import prefix
  /// or type arguments, so it can be written elsewhere as it is.
  final bool isPlain;

  /// The shared widget whose `build` returns this call directly; null
  /// for any other call.
  final _SharedWidget? shared;

  /// The call's code, exactly as written.
  final String source;

  /// The settings naming what is shown, such as the icon, rather than how:
  /// a difference in them is a choice, never a drift.
  final Set<String> choices;

  /// Whether the widget is the project's own rather than Flutter's or a
  /// package's.
  final bool isProjectWidget;

  /// Where it is built.
  final RepeatedSettingsLocation location;

  /// Each styling setting's normalized code, by setting name.
  final Map<String, String> settings;

  /// Each styling setting's code as written, by setting name.
  final Map<String, String> sources;

  /// The widget's class, with its named constructor if any.
  final String widget;

  /// The argument called [name], or at the position it names; null for
  /// none.
  _Argument? argumentNamed(String name) =>
      arguments.where((argument) => argument.name == name).firstOrNull;

  /// The settings as written, one `name: value` after the other.
  String display() =>
      [for (final name in _sortedNames()) _named(name, sources[name]!)]
          .join(', ');

  /// The normalized settings in name order, leaving out [except].
  String key({String? except}) => [
    for (final name in _sortedNames())
      if (name != except) _named(name, settings[name]!),
  ].join(', ');

  /// `name: value`, or just the value of a positional setting.
  static String _named(String name, String value) =>
      name.startsWith(RepeatedSettingsFinding.positionalPrefix)
      ? value
      : '$name: $value';

  List<String> _sortedNames() => settings.keys.toList()..sort();
}
