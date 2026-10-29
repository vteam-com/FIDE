/// Converts between character offsets in a text and 1-based line and
/// column positions.
class TextOffsets {
  /// The 1-based line and column of [offset] in [text]; offsets past the
  /// end count as the end.
  static ({int line, int column}) positionOf(String text, int offset) {
    final end = offset.clamp(0, text.length);
    final before = text.substring(0, end);
    final lastNewline = before.lastIndexOf('\n');
    return (
      line: '\n'.allMatches(before).length + 1,
      column: end - lastNewline,
    );
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
}
