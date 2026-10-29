part of 'outline_parser.dart';

/// Outlines YAML by its top-level keys.
class YamlOutlineParser extends OutlineParser {
  /// Creates the parser.
  const YamlOutlineParser();

  @override
  List<OutlineNode> parse(String content) {
    final document = loadYaml(content);
    if (document is! Map) return const [];

    final nodes = <OutlineNode>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      // Top-level keys start at column 1
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          line.startsWith(' ') ||
          line.startsWith('\t') ||
          !line.contains(':')) {
        continue;
      }
      final key = line.split(':')[0].trim();
      if (document.containsKey(key)) {
        nodes.add(
          OutlineNode(
            name: key,
            type: 'YAML Key',
            line: i + 1,
            column: line.indexOf(key) + 1,
          ),
        );
      }
    }
    return nodes;
  }
}
