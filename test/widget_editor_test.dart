import 'package:fide/models/outline_kind.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/widget_wrapper.dart';
import 'package:fide/services/outline_parser.dart';
import 'package:fide/services/widget_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// [body], the widgets a `build` method returns, in a file.
String _build(String body) =>
    'class A {\n  Widget build(BuildContext context) {\n    return $body;\n'
    '  }\n}\n';

/// The editor of the outline entry [name] of [content], the [index]th one
/// so named.
WidgetEditor _editorOf(String content, String name, {int index = 0}) {
  final nodes = const DartOutlineParser()
      .parse(content)
      .where((node) => node.name == name)
      .toList();
  return WidgetEditor.find(content, nodes[index])!;
}

/// The text [edit] makes of [content]'s widgets, from the `return` on.
String? _bodyAfter(WidgetEditResult? edit) {
  final content = edit?.content;
  if (content == null) return null;
  final start = content.indexOf('return ') + 'return '.length;
  return content.substring(start, content.lastIndexOf(';'));
}

void main() {
  test('wraps a widget, starting the edit where it started', () {
    final content = _build("Center(child: const Text('a'))");
    final edit = _editorOf(content, 'Text').wrap(WidgetWrapper.padding);

    expect(
      _bodyAfter(edit),
      'Center(child: Padding(padding: const EdgeInsets.all(8), '
      "child: const Text('a'),))",
    );
    expect(edit.content.substring(edit.offset), startsWith('Padding('));
  });

  test('wraps in a list of children or a builder', () {
    final content = _build('Text(title)');
    final editor = _editorOf(content, 'Text');

    expect(
      _bodyAfter(editor.wrap(WidgetWrapper.column)),
      'Column(children: [Text(title)],)',
    );
    expect(
      _bodyAfter(editor.wrap(WidgetWrapper.builder)),
      'Builder(builder: (context) => Text(title),)',
    );
  });

  test('wraps a helper call and a variable', () {
    final content = _build('Column(children: [_buildHeader(), child])');

    expect(
      _bodyAfter(
        _editorOf(content, '_buildHeader()').wrap(WidgetWrapper.center),
      ),
      'Column(children: [Center(child: _buildHeader(),), child])',
    );
    expect(
      _bodyAfter(_editorOf(content, 'child').wrap(WidgetWrapper.expanded)),
      'Column(children: [_buildHeader(), Expanded(child: child,)])',
    );
  });

  test('a wrapper named by the developer must name a widget', () {
    expect(WidgetWrapper.named(' material.Card ')?.name, 'material.Card');
    expect(WidgetWrapper.named('ListView.builder')?.name, 'ListView.builder');
    expect(WidgetWrapper.named('Card(child: x)'), isNull);
    expect(WidgetWrapper.named(''), isNull);
  });

  test('removes a widget in favor of its child', () {
    final content = _build("Padding(padding: p, child: Text('a'))");
    final editor = _editorOf(content, 'Padding');

    expect(editor.canRemove, isTrue);
    expect(_bodyAfter(editor.remove()), "Text('a')");
  });

  test('removes a widget with one child, or several in a list', () {
    final single = _build("Column(children: [Text('a')])");
    expect(_bodyAfter(_editorOf(single, 'Column').remove()), "Text('a')");

    final several = _build("Column(children: [Text('a'), Text('b')])");
    expect(_editorOf(several, 'Column').canRemove, isFalse);

    final nested = _build(
      "Column(children: [Row(children: [Text('a'), Text('b'),]), Text('c')])",
    );
    expect(
      _bodyAfter(_editorOf(nested, 'Row').remove()),
      "Column(children: [Text('a'), Text('b'), Text('c')])",
    );
  });

  test('a widget laying out nothing or a reference cannot be removed', () {
    final content = _build("Center(child: _buildHeader())");

    expect(_editorOf(content, '_buildHeader()').canRemove, isFalse);
    expect(_editorOf(_build("Text('a')"), 'Text').canRemove, isFalse);
  });

  test('swaps a widget with the widget whose slot it fills', () {
    final content = _build(
      "Padding(padding: p, child: const Center(child: Text('a')))",
    );
    final editor = _editorOf(content, 'Center');

    expect(editor.canSwapWithParent, isTrue);
    final edit = editor.swapWithParent()!;
    // The constant `Center` now holds a `Padding` that may not be one
    expect(
      _bodyAfter(edit),
      "Center(child: Padding(padding: p, child: Text('a')))",
    );
    expect(edit.content.substring(edit.offset), startsWith('Center('));
  });

  test('swaps through any slot of the parent', () {
    final content = _build('Scaffold(body: Center(child: list))');

    expect(
      _bodyAfter(_editorOf(content, 'Center').swapWithParent()),
      'Center(child: Scaffold(body: list))',
    );
  });

  test('a widget without a child or parent widget cannot swap', () {
    expect(
      _editorOf(_build("Center(child: Text('a'))"), 'Text').canSwapWithParent,
      isFalse,
    );
    expect(
      _editorOf(_build('Center(child: x)'), 'Center').canSwapWithParent,
      isFalse,
    );
    expect(
      _editorOf(
        _build("Column(children: [Center(child: x)])"),
        'Center',
      ).canSwapWithParent,
      isFalse,
    );
  });

  test('moves a widget among the widgets of its list', () {
    final content = _build("Column(children: [Text('a'), Icon(i), Text('c')])");
    final icon = _editorOf(content, 'Icon');

    final up = icon.moveUp()!;
    expect(_bodyAfter(up), "Column(children: [Icon(i), Text('a'), Text('c')])");
    expect(up.content.substring(up.offset), startsWith('Icon(i)'));

    final down = icon.moveDown()!;
    expect(
      _bodyAfter(down),
      "Column(children: [Text('a'), Text('c'), Icon(i)])",
    );
    expect(down.content.substring(down.offset), startsWith('Icon(i)'));
  });

  test('the first and last widgets of a list move one way only', () {
    final content = _build("Row(children: [Text('a'), Text('b')])");
    final first = _editorOf(content, 'Text');
    final last = _editorOf(content, 'Text', index: 1);

    expect([first.canMoveUp, first.canMoveDown], [false, true]);
    expect([last.canMoveUp, last.canMoveDown], [true, false]);
    expect(_editorOf(_build('Center(child: x)'), 'Center').canMoveUp, isFalse);
  });

  test('finds nothing where the outline entry is no longer', () {
    final content = _build("Text('a')");
    final node = const DartOutlineParser()
        .parse(content)
        .firstWhere((node) => node.name == 'Text');

    expect(WidgetEditor.find('class A {}\n', node), isNull);
    expect(WidgetEditor.find(_build("Icon(i)"), node), isNull);
    expect(
      WidgetEditor.find(
        content,
        const OutlineNode(name: 'A', kind: OutlineKind.dartClass, line: 1),
      ),
      isNull,
    );
  });
}
