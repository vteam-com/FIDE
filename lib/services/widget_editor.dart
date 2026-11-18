import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/widget_wrapper.dart';
import 'package:fide/services/widget_creation.dart';

part 'widget_editor.entry_finder.dart';

/// A Dart file's text rewritten by a [WidgetEditor], unformatted, with
/// the offset where the widget edited starts in it.
typedef WidgetEditResult = ({String content, int offset});

/// One of a [WidgetEditor]'s edits, such as
/// `(editor) => editor.wrap(WidgetWrapper.center)`; null when it doesn't
/// apply to the widget.
typedef WidgetEdit = WidgetEditResult? Function(WidgetEditor editor);

/// One entry of a build function's widget tree, as the outline lists it,
/// found in a Dart file's text to rewrite it: wrapped in another widget,
/// replaced by the widgets it lays out, swapped with the widget whose slot
/// it fills, or moved among the widgets of its list.
///
/// Each edit returns the new text, to be formatted, or null when it
/// doesn't apply to this entry. Like the outline, it reads the code
/// without types.
class WidgetEditor {
  WidgetEditor._(this._content, this._widget);

  /// The text the entry was found in.
  final String _content;

  /// The expression the entry stands for: a widget created there, or one
  /// built elsewhere, such as `_buildHeader()` or `child`.
  final Expression _widget;

  /// Whether [moveDown] applies: the entry is in a list of widgets, before
  /// its last.
  bool get canMoveDown => moveDown() != null;

  /// Whether [moveUp] applies: the entry is in a list of widgets, after
  /// its first.
  bool get canMoveUp => moveUp() != null;

  /// Whether [remove] applies: the entry creates a widget laying out one
  /// child, or children in a list of widgets.
  bool get canRemove => remove() != null;

  /// Whether [swapWithParent] applies: the entry creates a widget with a
  /// child, filling a slot of the widget created around it.
  bool get canSwapWithParent => swapWithParent() != null;

  /// The widget-tree entry [node] of the outline of [content]; null when
  /// [node] isn't one, or isn't in [content] any more, such as after an
  /// edit the outline hasn't caught up with.
  static WidgetEditor? find(String content, OutlineNode node) {
    if (!node.kind.isWidget) return null;
    final parsed = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    final lineInfo = parsed.lineInfo;
    if (node.line < 1 || node.line > lineInfo.lineCount) return null;
    final finder = _EntryFinder(
      offset: lineInfo.getOffsetOfLine(node.line - 1) + node.column - 1,
      name: node.name,
    );
    parsed.unit.accept(finder);
    final found = finder.found;
    return found == null ? null : WidgetEditor._(content, found);
  }

  /// The entry swapped with the widget after it in its list.
  WidgetEditResult? moveDown() => _move(down: true);

  /// The entry swapped with the widget before it in its list.
  WidgetEditResult? moveUp() => _move(down: false);

  /// The created widget replaced by the widgets it lays out: its child,
  /// the only one of its children, or, when it is itself in a list of
  /// widgets, all its children.
  WidgetEditResult? remove() {
    final creation = WidgetCreation.of(_widget);
    if (creation == null) return null;
    final child = creation.child;
    if (child != null) return _replace(_widget, _sourceOf(child));
    final elements = creation.children?.elements;
    if (elements == null || elements.isEmpty) return null;
    if (_widget.parent is ListLiteral) {
      // From the first child to the last, without a comment that a
      // trailing comma could leave swallowing the code after it
      return _replace(
        _widget,
        _content.substring(elements.first.offset, elements.last.end),
      );
    }
    final only = elements.singleOrNull;
    return only is Expression ? _replace(_widget, _sourceOf(only)) : null;
  }

  /// The created widget and the widget whose slot it fills trading
  /// places: `Padding(child: Center(child: x))` becomes
  /// `Center(child: Padding(child: x))`.
  WidgetEditResult? swapWithParent() {
    final creation = WidgetCreation.of(_widget);
    final child = creation?.child;
    final slot = _widget.parent;
    final parent = slot?.parent?.parent;
    if (creation == null ||
        child == null ||
        slot is! NamedArgument ||
        parent is! Expression ||
        WidgetCreation.of(parent) == null) {
      return null;
    }
    // The parent, holding the widget's child where the widget was
    final inner = _sourceOf(parent).replaceRange(
      _widget.offset - parent.offset,
      _widget.end - parent.offset,
      _sourceOf(child),
    );
    // The widget, holding its parent where its child was, without a
    // `const` the parent may not allow
    final start = _constKeywordOf(_widget)?.next?.offset ?? _widget.offset;
    final outer = _content
        .substring(start, _widget.end)
        .replaceRange(child.offset - start, child.end - start, inner);
    return _replace(parent, outer);
  }

  /// The entry wrapped in [wrapper]: `Center(child: entry)`.
  WidgetEditResult wrap(WidgetWrapper wrapper) =>
      _replace(_widget, wrapper.wrap(_sourceOf(_widget)));

  /// The entry swapped with its neighbor in its list: the next one when
  /// [down], else the previous one; null when it has none there.
  WidgetEditResult? _move({required bool down}) {
    final list = _widget.parent;
    if (list is! ListLiteral) return null;
    final elements = list.elements;
    final neighborIndex = elements.indexOf(_widget) + (down ? 1 : -1);
    if (neighborIndex < 0 || neighborIndex >= elements.length) return null;
    final neighbor = elements[neighborIndex];
    final (first, second) = down ? (_widget, neighbor) : (neighbor, _widget);
    final content = _content
        .replaceRange(second.offset, second.end, _sourceOf(first))
        .replaceRange(first.offset, first.end, _sourceOf(second));
    return (
      content: content,
      offset: down ? second.end - _sourceOf(_widget).length : first.offset,
    );
  }

  /// [node] replaced by [replacement], the new text starting where [node]
  /// did.
  WidgetEditResult _replace(AstNode node, String replacement) => (
    content: _content.replaceRange(node.offset, node.end, replacement),
    offset: node.offset,
  );

  /// The source of [entity] in the text.
  String _sourceOf(SyntacticEntity entity) =>
      _content.substring(entity.offset, entity.end);

  /// The `const` keyword [widget] is created with, if any.
  static Token? _constKeywordOf(Expression widget) => switch (widget) {
    InstanceCreationExpression(:final keyword?)
        when keyword.keyword == Keyword.CONST =>
      keyword,
    _ => null,
  };
}
