import 'dart:ui';

import 'package:fide/services/preview_scanner.dart';

/// Writes a preview's size in its `@Preview(...)` annotation, so a
/// preview whose size followed the panel or the host's default renders the
/// same everywhere.
class PreviewSizeFixer {
  /// Creates the fixer.
  const PreviewSizeFixer();

  /// The `Preview` argument setting a preview's size.
  static const String _sizeArgument = 'size';

  /// [content] with annotation [annotation] of the preview labeled [label]
  /// set to [size], rounded up to whole pixels so nothing gets clipped;
  /// null when that annotation isn't a plain `Preview(...)`.
  String? withSize(
    String content, {
    required String label,
    required int annotation,
    required Size size,
  }) {
    final target = const PreviewScanner()
        .scan(content)
        .annotationOf(label, annotation);
    final start = target?.argumentsStart;
    if (target == null || start == null) return null;
    final argument =
        '$_sizeArgument: Size(${size.width.ceil()}, ${size.height.ceil()})';
    final existing = target.sizeArgument;
    if (existing != null) {
      return content.replaceRange(existing.start, existing.end, argument);
    }
    final arguments = content.substring(start, target.argumentsEnd).trimRight();
    final at = start + arguments.length;
    final insertion = arguments.trim().isEmpty
        ? argument
        : arguments.endsWith(',')
        ? ' $argument,'
        : ', $argument';
    return content.replaceRange(at, at, insertion);
  }
}
