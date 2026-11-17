/// Converts between character offsets in a text and 1-based line and
/// column positions, and edits a text at offsets.
class TextOffsets {
  /// The line separator [positionOf] counts.
  static const String _newline = '\n';

  /// [text] with each of [edits], offset → (length, replacement), applied
  /// from the end of the text so the offsets before it stay valid.
  ///
  /// Edits that don't overlap are applied in one pass over [text]; throws
  /// a [RangeError] when an edit reaches outside the text.
  static String applyEdits(String text, Map<int, (int, String)> edits) {
    final offsets = edits.keys.toList()..sort();
    final result = StringBuffer();
    var copied = 0;
    for (final offset in offsets) {
      if (offset < copied) return _applyOverlapping(text, edits, offsets);
      final (length, replacement) = edits[offset]!;
      final end = offset + length;
      RangeError.checkValidRange(offset, end, text.length);
      result
        ..write(text.substring(copied, offset))
        ..write(replacement);
      copied = end;
    }
    result.write(text.substring(copied));
    return result.toString();
  }

  /// The 1-based line and column of [offset] in [text]; offsets past the
  /// end count as the end.
  static ({int line, int column}) positionOf(String text, int offset) {
    final end = offset.clamp(0, text.length);
    var line = 1;
    var lastNewline = -1;
    for (
      var newline = text.indexOf(_newline);
      newline != -1 && newline < end;
      newline = text.indexOf(_newline, newline + 1)
    ) {
      line++;
      lastNewline = newline;
    }
    return (line: line, column: end - lastNewline);
  }

  /// The offset of 1-based [line] and [column] in [text], with the column
  /// clamped to the line; null when [line] is out of range.
  static int? offsetOf(String text, int line, {int column = 1}) {
    final lines = text.split('\n');
    if (line < 1 || line > lines.length) return null;
    var offset = 0;
    for (final previous in lines.take(line - 1)) {
      offset += previous.length + 1;
    }
    return offset + (column - 1).clamp(0, lines[line - 1].length);
  }

  /// [text] with [edits] applied one after the other from the last of
  /// [offsets] (sorted ascending), for edits that overlap.
  static String _applyOverlapping(
    String text,
    Map<int, (int, String)> edits,
    List<int> offsets,
  ) {
    var result = text;
    for (final offset in offsets.reversed) {
      final (length, replacement) = edits[offset]!;
      result = result.replaceRange(offset, offset + length, replacement);
    }
    return result;
  }
}
