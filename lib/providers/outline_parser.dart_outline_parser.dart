part of 'outline_parser.dart';

/// Outlines Dart: classes, functions, methods and top-level variables.
class DartOutlineParser extends OutlineParser {
  /// Creates the parser.
  const DartOutlineParser();

  @override
  List<OutlineNode> parse(String content) {
    final result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final visitor = _OutlineVisitor(content);
    result.unit.visitChildren(visitor);
    return visitor.nodes;
  }
}
