part of 'preview_scan.dart';

/// One preview annotation of a declaration: the constant the host
/// evaluates and, for a plain `Preview(...)`, where its arguments are in
/// the file, so its `size` can be written.
@immutable
class PreviewAnnotation {
  /// The annotation as a constant expression, such as
  /// `const Preview(name: 'Light')`.
  final String constant;

  /// The offset just past the `(` of a plain `Preview(...)`'s arguments;
  /// null for any other annotation, such as a `MultiPreview`, whose size
  /// is set elsewhere.
  final int? argumentsStart;

  /// The offset of the `)` closing those arguments.
  final int argumentsEnd;

  /// The offsets of the `size: ...` argument, when the annotation has one.
  final ({int start, int end})? sizeArgument;

  /// Creates the annotation.
  const PreviewAnnotation(
    this.constant, {
    this.argumentsStart,
    this.argumentsEnd = 0,
    this.sizeArgument,
  });

  /// Whether the annotation is a plain `Preview(...)` whose size can be
  /// written in it.
  bool get canSetSize => argumentsStart != null;
}
