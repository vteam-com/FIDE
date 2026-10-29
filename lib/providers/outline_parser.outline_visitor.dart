part of 'outline_parser.dart';

/// Collects Dart declarations into outline nodes, nesting members under
/// their class.
class _OutlineVisitor extends RecursiveAstVisitor<void> {
  final List<OutlineNode> nodes = [];
  final String fileContent;
  int _currentLevel = 0;

  _OutlineVisitor(this.fileContent);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _addNode(node.namePart.toString(), 'class', node.offset);
    _currentLevel++;
    super.visitClassDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addNode(node.name.toString(), 'function', node.offset);
    _currentLevel++;
    super.visitFunctionDeclaration(node);
    _currentLevel--;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addNode(
      node.name.toString(),
      'method',
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
      _addNode(node.name.toString(), 'variable', node.offset);
    }
    super.visitVariableDeclaration(node);
  }

  /// Appends a [type] node named [name] starting at source [offset].
  void _addNode(
    String name,
    String type,
    int offset, {
    bool isOverride = false,
  }) {
    final position = TextOffsets.positionOf(fileContent, offset);
    nodes.add(
      OutlineNode(
        name: name,
        type: type,
        line: position.line,
        column: position.column,
        level: _currentLevel,
        isOverride: isOverride,
      ),
    );
  }
}
