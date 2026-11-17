part of 'outline_parser.dart';

/// Collects Dart declarations into outline nodes, nesting members under
/// their class.
class _OutlineVisitor extends RecursiveAstVisitor<void> {
  final List<OutlineNode> nodes = [];

  /// Where each line of the parsed text starts, to place the nodes.
  final LineInfo lineInfo;
  int _currentLevel = 0;

  _OutlineVisitor(this.lineInfo);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _addNode(node.namePart.toString(), OutlineKind.dartClass, node.offset);
    _currentLevel++;
    super.visitClassDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addNode(node.name.toString(), OutlineKind.function, node.offset);
    _currentLevel++;
    super.visitFunctionDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addNode(
      node.name.toString(),
      OutlineKind.method,
      node.offset,
      isOverride: node.metadata.any((a) => a.name.name == 'override'),
    );
    _currentLevel++;
    super.visitMethodDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_currentLevel == 0) {
      _addNode(node.name.toString(), OutlineKind.variable, node.offset);
    }
    super.visitVariableDeclaration(node);
  }

  /// Appends a [kind] node named [name] starting at source [offset].
  void _addNode(
    String name,
    OutlineKind kind,
    int offset, {
    bool isOverride = false,
  }) {
    final position = lineInfo.getLocation(offset);
    nodes.add(
      OutlineNode(
        name: name,
        kind: kind,
        line: position.lineNumber,
        column: position.columnNumber,
        level: _currentLevel,
        isOverride: isOverride,
      ),
    );
  }
}
