part of 'widget_editor.dart';

/// Finds the expression an outline widget-tree entry stands for: the
/// one named [_name] whose name starts at [_offset], where the outline
/// placed the entry.
class _EntryFinder extends GeneralizingAstVisitor<void> {
  /// Creates a finder for the entry named [_name] placed at [_offset].
  _EntryFinder({required this._offset, required this._name});

  /// The entry's expression once found; null until then.
  Expression? found;

  /// The entry's name in the outline: a widget's (`ListView.builder`), a
  /// helper call's (`_buildHeader()`) or a variable's (`child`).
  final String _name;

  /// Where the outline placed the entry: a widget's name, after any
  /// `const`, or a helper call's method name.
  final int _offset;

  @override
  void visitNode(AstNode node) {
    // Only the nodes around the offset can hold the entry
    if (found != null || _offset < node.offset || _offset >= node.end) {
      return;
    }
    if (node is Expression && _isEntry(node)) {
      found = node;
      return;
    }
    super.visitNode(node);
  }

  /// Whether [expression] is the entry, placed as the outline places it.
  bool _isEntry(Expression expression) {
    final creation = WidgetCreation.of(expression);
    if (creation != null) {
      return creation.nameOffset == _offset && creation.name == _name;
    }
    if (expression is MethodInvocation) {
      // A helper's entry is named after its call, its arguments left out
      final method = expression.methodName;
      return method.offset == _offset && _name.endsWith('${method.name}()');
    }
    return expression.offset == _offset && expression.toSource() == _name;
  }
}
