part of 'preview_scan.dart';

/// A parameter of a widget's constructor, for the previews generated for
/// the widget.
@immutable
class PreviewParameter {
  /// The parameter's name.
  final String name;

  /// The parameter's type as written, such as `ValueChanged<int>?`; null
  /// when the type isn't known (a `super.` parameter).
  final String? type;

  /// Whether the parameter is named rather than positional.
  final bool isNamed;

  /// Whether a call must pass the parameter.
  final bool isRequired;

  /// Creates the parameter.
  const PreviewParameter({
    required this.name,
    required this.type,
    required this.isNamed,
    required this.isRequired,
  });

  /// Whether the parameter's type accepts null.
  bool get isNullable => type?.endsWith('?') ?? false;
}
