part of 'preview_scan.dart';

/// A public class of a scanned file, with the constructor code calls to
/// build it: a widget to preview, or a value a constructor requires.
@immutable
class PreviewClass {
  /// The class name.
  final String name;

  /// The 1-based line of the class.
  final int line;

  /// Whether the class extends a widget class: its superclass's name
  /// ends with `Widget`, such as `StatelessWidget`.
  final bool isWidget;

  /// The names of the classes it extends, implements or mixes in, without
  /// prefix or type arguments.
  final List<String> supertypes;

  /// Whether code can build it: it is concrete, or abstract with a public
  /// factory constructor, and has a public constructor or none declared.
  final bool isConstructible;

  /// The name of the constructor code calls: empty for the unnamed one.
  final String constructorName;

  /// Whether that constructor is `const`.
  final bool isConstConstructor;

  /// That constructor's parameters, in declaration order.
  final List<PreviewParameter> parameters;

  /// Creates the class.
  const PreviewClass({
    required this.name,
    required this.line,
    this.isWidget = false,
    this.supertypes = const [],
    this.isConstructible = true,
    this.constructorName = '',
    this.isConstConstructor = false,
    this.parameters = const [],
  });

  /// The call to the constructor without its arguments, such as
  /// `MyWidget.compact`.
  String get constructorCall =>
      constructorName.isEmpty ? name : '$name.$constructorName';

  /// The parameters a call must pass.
  List<PreviewParameter> get requiredParameters =>
      parameters.where((parameter) => parameter.isRequired).toList();
}
