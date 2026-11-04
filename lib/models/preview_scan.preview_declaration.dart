part of 'preview_scan.dart';

/// A function, static method or constructor annotated with `@Preview` (or
/// a `Preview` or `MultiPreview` subclass), which the preview host calls to
/// build the previewed widget.
@immutable
class PreviewDeclaration {
  /// What the Preview panel calls the declaration: `myPreview`,
  /// `MyWidget.preview` or `MyWidget`.
  final String label;

  /// The Dart expression calling the declaration, such as `myPreview()`.
  final String invocation;

  /// Each preview annotation, in source order.
  final List<PreviewAnnotation> annotations;

  /// The 1-based line of the declaration.
  final int line;

  /// The declaration's source, to tell which widgets it builds.
  final String source;

  /// Creates the declaration.
  const PreviewDeclaration({
    required this.label,
    required this.invocation,
    required this.annotations,
    required this.line,
    required this.source,
  });

  /// Whether the declaration builds the widget class [className].
  bool builds(String className) =>
      RegExp('\\b${RegExp.escape(className)}\\b').hasMatch(source);
}
