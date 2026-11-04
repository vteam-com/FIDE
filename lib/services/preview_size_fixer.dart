import 'package:fide/services/preview_scanner.dart';

/// Writes a preview's size in its `@Preview(...)` annotation: each of its
/// width and height fixed or Auto, as the developer picked in the Preview
/// panel.
class PreviewSizeFixer {
  /// Creates the fixer.
  const PreviewSizeFixer();

  /// The `size:` argument fixing [width] and [height], each rounded up to
  /// whole pixels so nothing gets clipped, the one null left Auto, such as
  /// `size: Size(360, 48)` or `size: Size.fromHeight(48)`; null when both
  /// are Auto.
  static String? sizeArgumentFor({double? width, double? height}) {
    final size = switch ((width?.ceil(), height?.ceil())) {
      (final w?, final h?) => 'Size($w, $h)',
      (final w?, null) => 'Size.fromWidth($w)',
      (null, final h?) => 'Size.fromHeight($h)',
      (null, null) => null,
    };
    return size == null ? null : '${PreviewScanner.sizeArgument}: $size';
  }

  /// [content] with annotation [annotation] of the preview labeled [label]
  /// sized as [sizeArgumentFor] writes [width] and [height], without a
  /// size when both are null; null when that annotation isn't a plain
  /// `Preview(...)` or already says so.
  String? withSize(
    String content, {
    required String label,
    required int annotation,
    double? width,
    double? height,
  }) {
    final target = const PreviewScanner()
        .scan(content)
        .annotationOf(label, annotation);
    final start = target?.argumentsStart;
    if (target == null || start == null) return null;
    final argument = sizeArgumentFor(width: width, height: height);
    final existing = target.sizeArgument;
    if (argument == null) {
      final removal = target.sizeRemoval;
      return removal == null
          ? null
          : content.replaceRange(removal.start, removal.end, '');
    }
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
