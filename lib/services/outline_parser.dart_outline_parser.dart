part of 'outline_parser.dart';

/// Outlines Dart: classes, functions, methods and top-level variables, and
/// under each function returning widgets (`build`), the widget tree it
/// returns.
class DartOutlineParser extends OutlineParser {
  /// Creates the parser.
  const DartOutlineParser();

  @override
  List<OutlineNode> parse(String content) {
    final result = parseDart(content);
    final visitor = _OutlineVisitor(result.lineInfo);
    result.unit.visitChildren(visitor);
    return visitor.nodes;
  }
}
