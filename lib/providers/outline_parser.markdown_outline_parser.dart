part of 'outline_parser.dart';

/// Outlines Markdown by its `#` headings.
class MarkdownOutlineParser extends OutlineParser {
  /// Creates the parser.
  const MarkdownOutlineParser();

  @override
  List<OutlineNode> parse(String content) {
    final lines = content.split('\n');
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].startsWith('#')) _heading(lines[i], i + 1),
    ];
  }

  /// The heading on [line], whose 1-based number is [lineNumber].
  static OutlineNode _heading(String line, int lineNumber) {
    final level = line.split(' ')[0].length;
    return OutlineNode(
      name: line.substring(level).trim(),
      type: 'Heading ${level.clamp(1, AppMetric.markdownMaxHeadingLevel)}',
      line: lineNumber,
      // Just after the # characters
      column: level + 1,
      level: level - 1,
    );
  }
}
