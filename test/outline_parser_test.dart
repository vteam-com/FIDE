import 'package:fide/models/outline_kind.dart';
import 'package:fide/services/outline_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks a parser by extension', () {
    expect(OutlineParser.forFile('a/b.dart'), isA<DartOutlineParser>());
    expect(OutlineParser.forFile('README.MD'), isA<MarkdownOutlineParser>());
    expect(OutlineParser.forFile('pubspec.yml'), isA<YamlOutlineParser>());
    expect(OutlineParser.forFile('data.json'), isNull);
  });

  test('Dart outlines nest members and give 1-based positions', () {
    final nodes = const DartOutlineParser().parse(
      'int top = 1;\n\nclass A {\n  void run() {}\n}\n',
    );

    expect(
      [for (final n in nodes) (n.name, n.kind, n.line, n.level)],
      [
        ('top', OutlineKind.variable, 1, 0),
        ('A', OutlineKind.dartClass, 3, 0),
        ('run', OutlineKind.method, 4, 1),
      ],
    );
    expect(nodes.last.column, 3);
  });

  test('Dart outline positions follow the lines, CRLF ones included', () {
    const source =
        '/// Doc\nint a = 1, b = 2;\n\nclass A {\n  int f = 0;\n'
        '  void run() {}\n\n    void deep() {}\n}\n\nvoid main() {}\n';
    final expected = [
      ('a', 2, 5),
      ('b', 2, 12),
      ('A', 4, 1),
      ('run', 6, 3),
      ('deep', 8, 5),
      ('main', 11, 1),
    ];

    for (final text in [source, source.replaceAll('\n', '\r\n')]) {
      final nodes = const DartOutlineParser().parse(text);
      expect([for (final n in nodes) (n.name, n.line, n.column)], expected);
    }
  });

  test('Dart outlines mark @override methods', () {
    final nodes = const DartOutlineParser().parse(
      'class A {\n  @override\n  String toString() => "";\n  void run() {}\n}\n',
    );

    expect([for (final n in nodes) n.isOverride], [false, true, false]);
  });

  group('Dart widget trees', () {
    /// The outline of [source] as (name, kind, level) records.
    List<(String, OutlineKind, int)> outline(String source) => [
      for (final node in const DartOutlineParser().parse(source))
        (node.name, node.kind, node.level),
    ];

    test('nest each widget under the slot it fills, leaving out padding, '
        'styles and other values', () {
      const source = '''
class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final footer = Text('end');
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            if (busy) const Spinner.small() else Text('idle', style: TextStyle()),
            for (final item in items) Item(item),
            ...items.map((item) => Tile(item)),
            _buildHeader(),
            footer,
          ],
        ),
      ),
    );
  }
}
''';

      expect(outline(source), [
        ('Home', OutlineKind.dartClass, 0),
        ('build', OutlineKind.method, 1),
        ('Scaffold', OutlineKind.widget, 2),
        ('AppBar', OutlineKind.widget, 3),
        ('Text', OutlineKind.widget, 4),
        ('Padding', OutlineKind.widget, 3),
        ('Column', OutlineKind.widget, 4),
        ('Spinner.small', OutlineKind.widget, 5),
        ('Text', OutlineKind.widget, 5),
        ('Item', OutlineKind.widget, 5),
        ('Tile', OutlineKind.widget, 5),
        ('_buildHeader()', OutlineKind.widgetReference, 5),
        ('footer', OutlineKind.widgetReference, 5),
      ]);
    });

    test('follow builders and branches; only child slots outline '
        'variables', () {
      const source = '''
Widget panel(bool wide, Widget? child, String name) => LayoutBuilder(
  builder: (context, constraints) {
    return wide
        ? Row(children: [child ?? Empty()])
        : ListTile(title: name, leading: Icon(Icons.add), trailing: _badge());
  },
);

void tap() => showDialog(builder: (context) => AlertDialog());
''';

      expect(outline(source), [
        ('panel', OutlineKind.function, 0),
        ('LayoutBuilder', OutlineKind.widget, 1),
        ('Row', OutlineKind.widget, 2),
        ('child', OutlineKind.widgetReference, 3),
        ('Empty', OutlineKind.widget, 3),
        ('ListTile', OutlineKind.widget, 2),
        ('Icon', OutlineKind.widget, 3),
        ('_badge()', OutlineKind.widgetReference, 3),
        ('tap', OutlineKind.function, 0),
      ]);
    });

    test('keep source order around local functions', () {
      const source = '''
Widget build() {
  Widget cell(String text) => Text(text);
  return Row(children: [cell('a')]);
}
''';

      expect(outline(source), [
        ('build', OutlineKind.function, 0),
        ('cell', OutlineKind.function, 1),
        ('Text', OutlineKind.widget, 2),
        ('Row', OutlineKind.widget, 1),
        ('cell()', OutlineKind.widgetReference, 2),
      ]);
    });
  });

  test('Markdown outlines headings by level', () {
    final nodes = const MarkdownOutlineParser().parse('# Title\ntext\n## Sub');

    expect(
      [for (final n in nodes) (n.name, n.kind, n.line, n.level)],
      [
        ('Title', OutlineKind.heading1, 1, 0),
        ('Sub', OutlineKind.heading2, 3, 1),
      ],
    );
  });

  test('YAML outlines top-level keys only', () {
    final nodes = const YamlOutlineParser().parse(
      'name: x\n# note\ndependencies:\n  path: any\n',
    );

    expect(
      [for (final n in nodes) (n.name, n.kind, n.line)],
      [
        ('name', OutlineKind.yamlKey, 1),
        ('dependencies', OutlineKind.yamlKey, 3),
      ],
    );
  });

  test('Markdown headings deeper than six share the last heading kind', () {
    final nodes = const MarkdownOutlineParser().parse(
      '###### Six\n####### Seven',
    );

    expect(
      [for (final n in nodes) n.kind],
      [OutlineKind.heading6, OutlineKind.heading6],
    );
  });

  test('only Dart declarations count their consumers', () {
    expect(
      [
        for (final kind in OutlineKind.values)
          if (kind.isCountable) kind,
      ],
      [
        OutlineKind.dartClass,
        OutlineKind.function,
        OutlineKind.method,
        OutlineKind.variable,
      ],
    );
  });
}
