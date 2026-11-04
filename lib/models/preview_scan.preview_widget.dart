part of 'preview_scan.dart';

/// A public widget class of a scanned file, with the constructor a
/// generated preview calls.
@immutable
class PreviewWidget {
  /// The class name.
  final String name;

  /// The 1-based line of the class.
  final int line;

  /// The name of the constructor a preview calls: empty for the unnamed
  /// one.
  final String constructorName;

  /// Whether that constructor is `const`.
  final bool isConstConstructor;

  /// That constructor's parameters, in declaration order.
  final List<PreviewParameter> parameters;

  /// Creates the widget.
  const PreviewWidget({
    required this.name,
    required this.line,
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
