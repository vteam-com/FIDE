part of 'dry_analyzer.dart';

/// An argument a widget is built with, as written.
class _Argument {
  _Argument(
    this.name,
    this.source, {
    this.field,
    this.parameter,
    this.imported = const [],
    this.isMovable = false,
  });

  /// The field of the enclosing class the argument reads, as the `text`
  /// of `Text(text)` in a shared widget's `build`; null for anything else.
  final String? field;

  /// The declarations the value names through its file's imports, such as
  /// `BoxFit` in `BoxFit.fitHeight`: what code moved elsewhere imports.
  final List<Element> imported;

  /// Whether the value reads no state but the `context` of a `build`
  /// method, so the same code works in another widget's `build`.
  final bool isMovable;

  /// The parameter's name, or [DryFinding.positionalPrefix] and its index
  /// for a positional argument.
  final String name;

  /// The widget's parameter it is passed to; null when unresolved.
  final FormalParameterElement? parameter;

  /// The value's code, exactly as written.
  final String source;

  /// Whether the argument is passed by position.
  bool get isPositional => name.startsWith(DryFinding.positionalPrefix);
}
