/// One entry of the outline: a declaration, heading or key with where it
/// starts and how deeply it is nested.
class OutlineNode {
  /// Displayed name.
  final String name;

  /// Kind, e.g. `class`, `Heading 2` or `YAML Key`.
  final String type;

  /// 1-based line it starts on.
  final int line;

  /// 1-based column it starts at.
  final int column;

  /// Nesting depth, 0 for top level.
  final int level;

  /// Creates an outline entry.
  const OutlineNode({
    required this.name,
    required this.type,
    required this.line,
    this.column = 1,
    this.level = 0,
  });
}
