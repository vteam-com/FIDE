part of 'outline_parser.dart';

/// Adds one outline entry: its [name], [kind], source [offset] and
/// nesting [level].
typedef _AddEntry = void Function(
  String name,
  OutlineKind kind,
  int offset,
  int level,
);

/// Reads the widget tree a function returns from its code alone: the
/// widgets it returns, then the widgets in each one's slots (`child`,
/// `children`, `body`, `title`, `builder`, ...), one level deeper each.
///
/// Without types, a constructor call is a widget by the slot it fills, so
/// `padding: EdgeInsets.all(8)` or `style: TextStyle(...)` stay out.
class _WidgetTree {
  /// Creates a reader adding each widget it finds through [_add].
  _WidgetTree(this._add);

  /// The named arguments that hold a widget in any widget: whatever fills
  /// them, a variable included, is a widget.
  static const Set<String> _childSlots = {
    ...WidgetCreation.singleChildSlots,
    ...WidgetCreation.multiChildSlots,
    'body',
    'home',
  };

  /// The other named arguments Flutter's widgets fill with widgets. Some
  /// widgets take a text or an icon there instead (`MaterialApp.title`),
  /// so only the widgets created there, and helpers' results, are read.
  static const Set<String> _widgetSlots = {
    'actions',
    'activeIcon',
    'appBar',
    'avatar',
    'background',
    'bottom',
    'bottomNavigationBar',
    'bottomSheet',
    'content',
    'counter',
    'deleteIcon',
    'destinations',
    'drawer',
    'endDrawer',
    'error',
    'flexibleSpace',
    'floatingActionButton',
    'footer',
    'header',
    'helper',
    'hint',
    'icon',
    'label',
    'leading',
    'persistentFooterButtons',
    'placeholder',
    'prefix',
    'prefixIcon',
    'secondary',
    'secondaryBackground',
    'selectedIcon',
    'subtitle',
    'suffix',
    'suffixIcon',
    'tabs',
    'title',
    'trailing',
  };

  /// How the names of the callbacks building a widget end, compared
  /// without case: `builder`, `itemBuilder`, `separatorBuilder`.
  static const String _builderSuffix = 'builder';

  /// What a return type names when the function returns widgets: `Widget`,
  /// `Widget?`, `PreferredSizeWidget`, `List<Widget>`.
  static const String _widgetType = 'Widget';

  final _AddEntry _add;

  /// Adds the widgets [body] returns, at [level].
  void addReturnedBy(FunctionBody body, int level) {
    for (final returned in _ReturnCollector.returnedBy(body)) {
      _addValue(returned, level, isChildSlot: true);
    }
  }

  /// Adds [invocation], a call to a widget-building helper or a chain of
  /// calls, at [level]: a chain such as
  /// `items.map((item) => Text(item)).toList()` adds the widgets its
  /// callbacks return, a helper (`_buildHeader()`, and in a child slot any
  /// call) its name.
  void _addCall(
    MethodInvocation invocation,
    int level, {
    required bool isChildSlot,
  }) {
    final target = invocation.target;
    final isHelper = target == null || target is ThisExpression;
    final callbacks = isHelper
        ? const <FunctionExpression>[]
        : _callbacksOf(invocation);
    for (final callback in callbacks) {
      addReturnedBy(callback.body, level);
    }
    if (callbacks.isEmpty && (isHelper || isChildSlot)) {
      final name = invocation.methodName;
      final prefix = target == null || isHelper ? '' : '${target.toSource()}.';
      _add(
        '$prefix${name.name}()',
        OutlineKind.widgetReference,
        name.offset,
        level,
      );
    }
  }

  /// Adds the widgets [element], an entry of a list of widgets, holds at
  /// [level]: both branches of an `if`, the body of a `for`, what a spread
  /// holds.
  void _addElement(
    CollectionElement element,
    int level, {
    required bool isChildSlot,
  }) {
    switch (element) {
      case Expression():
        _addValue(element, level, isChildSlot: isChildSlot);
      case IfElement(:final thenElement, :final elseElement):
        _addElement(thenElement, level, isChildSlot: isChildSlot);
        if (elseElement != null) {
          _addElement(elseElement, level, isChildSlot: isChildSlot);
        }
      case ForElement(:final body):
        _addElement(body, level, isChildSlot: isChildSlot);
      case SpreadElement(:final expression):
        _addValue(expression, level, isChildSlot: isChildSlot);
      case NullAwareElement(:final value):
        _addValue(value, level, isChildSlot: isChildSlot);
      default:
      // A map entry holds no widget tree
    }
  }

  /// Adds the widgets [value], the content of a slot, holds at [level];
  /// [isChildSlot] says whatever fills the slot is a widget, so a variable
  /// there is added too. Text, numbers, icons and the like add nothing.
  void _addValue(Expression value, int level, {required bool isChildSlot}) {
    final creation = WidgetCreation.of(value);
    if (creation != null) {
      _addWidget(creation, level);
      return;
    }
    switch (value) {
      case ParenthesizedExpression(:final expression) ||
          AsExpression(:final expression) ||
          PostfixExpression(operand: final expression):
        _addValue(expression, level, isChildSlot: isChildSlot);
      case ConditionalExpression(:final thenExpression, :final elseExpression):
        _addValue(thenExpression, level, isChildSlot: isChildSlot);
        _addValue(elseExpression, level, isChildSlot: isChildSlot);
      case BinaryExpression(:final leftOperand, :final rightOperand)
          when value.operator.type == TokenType.QUESTION_QUESTION:
        _addValue(leftOperand, level, isChildSlot: isChildSlot);
        _addValue(rightOperand, level, isChildSlot: isChildSlot);
      case SwitchExpression(:final cases):
        for (final switchCase in cases) {
          _addValue(switchCase.expression, level, isChildSlot: isChildSlot);
        }
      case ListLiteral(:final elements):
        for (final element in elements) {
          _addElement(element, level, isChildSlot: isChildSlot);
        }
      case FunctionExpression(:final body):
        addReturnedBy(body, level);
      case MethodInvocation():
        _addCall(value, level, isChildSlot: isChildSlot);
      case Identifier() || PropertyAccess() || IndexExpression()
          when isChildSlot:
        _add(
          value.toSource(),
          OutlineKind.widgetReference,
          value.offset,
          level,
        );
    }
  }

  /// Adds the widget [creation] at [level], then the widgets in the slots
  /// of its arguments one level deeper.
  void _addWidget(WidgetCreation creation, int level) {
    _add(creation.name, OutlineKind.widget, creation.nameOffset, level);
    for (final argument
        in creation.arguments.arguments.whereType<NamedArgument>()) {
      final slot = argument.name.lexeme;
      final isChildSlot =
          _childSlots.contains(slot) ||
          slot.toLowerCase().endsWith(_builderSuffix);
      if (isChildSlot || _widgetSlots.contains(slot)) {
        _addValue(
          argument.argumentExpression,
          level + 1,
          isChildSlot: isChildSlot,
        );
      }
    }
  }

  /// Whether [returnType] says a function returns widgets.
  static bool returnsWidgets(TypeAnnotation? returnType) =>
      returnType?.toSource().contains(_widgetType) ?? false;

  /// The callbacks passed along the chain of calls ending in [invocation],
  /// in source order: `(item) => Text(item)` in
  /// `items.map((item) => Text(item)).toList()`.
  static List<FunctionExpression> _callbacksOf(MethodInvocation invocation) {
    final links = <MethodInvocation>[];
    for (
      Expression? link = invocation;
      link is MethodInvocation;
      link = link.target
    ) {
      links.insert(0, link);
    }
    return [
      for (final link in links)
        ...link.argumentList.arguments.whereType<FunctionExpression>(),
    ];
  }
}
