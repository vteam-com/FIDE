part of 'app_widget_localizer.dart';

/// An app widget built in a file: its arguments, and whether it is a
/// constant, which can't take a closure.
typedef _AppWidget = ({ArgumentList arguments, bool isConst});

/// Collects the app widgets ([AppWidgetLocalizer._appWidgets]) a file
/// builds, in source order.
///
/// Without type resolution `MaterialApp(...)` parses as a method
/// invocation, and `MaterialApp.router(...)` as one on the target
/// `MaterialApp`; only `const`/`new` ones parse as instance creations, so
/// both node types are checked.
class _AppWidgetVisitor extends RecursiveAstVisitor<void> {
  /// The app widgets found.
  final List<_AppWidget> apps = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _add('${node.constructorName}', node.argumentList, isConst: node.isConst);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final method = node.methodName.name;
    _add(
      target == null ? method : '$target.$method',
      node.argumentList,
      isConst: node.inConstantContext,
    );
    super.visitMethodInvocation(node);
  }

  /// Records [arguments] when [callee], such as `MaterialApp.router` or
  /// `material.MaterialApp`, constructs an app widget.
  void _add(String callee, ArgumentList arguments, {required bool isConst}) {
    final names = callee.split('.');
    if (names.length > 1 &&
        names.last == AppWidgetLocalizer._routerConstructor) {
      names.removeLast();
    }
    if (AppWidgetLocalizer._appWidgets.contains(names.last)) {
      apps.add((arguments: arguments, isConst: isConst));
    }
  }
}
