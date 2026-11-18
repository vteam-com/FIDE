part of 'outline_parser.dart';

/// Collects Dart declarations into outline nodes, nesting members under
/// their class and, under a function returning widgets, the widget tree it
/// returns.
class _OutlineVisitor extends RecursiveAstVisitor<void> {
  /// Where each line of the parsed text starts, to place the nodes.
  final LineInfo lineInfo;

  int _currentLevel = 0;

  /// The nodes found with their source offset, in the order found.
  final List<({int offset, OutlineNode node})> _found = [];

  _OutlineVisitor(this.lineInfo);

  /// The nodes in source order: a widget tree is read whole when its
  /// function is reached, before the declarations nested in that function,
  /// such as a local function defined before the `return`.
  List<OutlineNode> get nodes {
    final order = List.generate(_found.length, (index) => index)
      ..sort((a, b) {
        final bySource = _found[a].offset.compareTo(_found[b].offset);
        return bySource != 0 ? bySource : a.compareTo(b);
      });
    return [for (final index in order) _found[index].node];
  }

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
    _addWidgetTree(node.returnType, node.functionExpression.body);
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
    _addWidgetTree(node.returnType, node.body);
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

  /// Appends a [kind] node named [name] starting at source [offset],
  /// nested at [level] (the current level by default).
  void _addNode(
    String name,
    OutlineKind kind,
    int offset, {
    int? level,
    bool isOverride = false,
  }) {
    final position = lineInfo.getLocation(offset);
    _found.add((
      offset: offset,
      node: OutlineNode(
        name: name,
        kind: kind,
        line: position.lineNumber,
        column: position.columnNumber,
        level: level ?? _currentLevel,
        isOverride: isOverride,
      ),
    ));
  }

  /// Nests the widget tree [body] returns under the function being
  /// visited, when its [returnType] says it returns widgets.
  void _addWidgetTree(TypeAnnotation? returnType, FunctionBody body) {
    if (!_WidgetTree.returnsWidgets(returnType)) return;
    _WidgetTree(
      (name, kind, offset, level) => _addNode(name, kind, offset, level: level),
    ).addReturnedBy(body, _currentLevel);
  }
}
