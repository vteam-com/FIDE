/// Converts between character offsets in a text and 1-based line and
/// column positions, and edits a text at offsets.
class TextOffsets {
  /// The characters a code formatter adds, removes or moves: whitespace,
  /// and the commas it adds after or removes from a last argument.
  static const Set<String> _layout = {' ', '\t', '\r', '\n', ','};

  /// The line separator [positionOf] counts.
  static const String _newline = '\n';

  /// The offset just past the line break at or after [offset] in [text];
  /// its end when no line break follows.
  static int lineEndAfter(String text, int offset) {
    final lineBreak = text.indexOf(_newline, offset);
    return lineBreak == -1 ? text.length : lineBreak + 1;
  }

  /// The offset of the start of the line [offset] is on in [text].
  static int lineStartOf(String text, int offset) =>
      offset == 0 ? 0 : text.lastIndexOf(_newline, offset - 1) + 1;

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

  /// The offset in [formatted], [text] laid out again by a code formatter,
  /// of the code at [offset] in [text]: found by counting the characters
  /// before it that the formatter keeps, everything but [_layout].
  static int formattedOffset(String text, String formatted, int offset) {
    var kept = 0;
    for (var i = 0; i < offset && i < text.length; i++) {
      if (!_layout.contains(text[i])) kept++;
    }
    var at = 0;
    for (; at < formatted.length; at++) {
      if (_layout.contains(formatted[at])) continue;
      if (kept == 0) break;
      kept--;
    }
    return at;
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
