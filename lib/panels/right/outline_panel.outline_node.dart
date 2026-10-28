part of 'outline_panel.dart';

/// Represents `OutlineNode`.
class OutlineNode {
  final String name;
  final String type;
  final int line;
  final int column;
  final int level;

  OutlineNode({
    required this.name,
    required this.type,
    required this.line,
    this.column = 1,
    this.level = 0,
  });
}
