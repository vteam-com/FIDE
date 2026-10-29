import 'package:fide/providers/outline_parser.dart';
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
      [for (final n in nodes) (n.name, n.type, n.line, n.level)],
      [
        ('top', 'variable', 1, 0),
        ('A', 'class', 3, 0),
        ('run', 'method', 4, 1),
      ],
    );
    expect(nodes.last.column, 3);
  });

  test('Markdown outlines headings by level', () {
    final nodes = const MarkdownOutlineParser().parse('# Title\ntext\n## Sub');

    expect(
      [for (final n in nodes) (n.name, n.type, n.line, n.level)],
      [('Title', 'Heading 1', 1, 0), ('Sub', 'Heading 2', 3, 1)],
    );
  });

  test('YAML outlines top-level keys only', () {
    final nodes = const YamlOutlineParser().parse(
      'name: x\n# note\ndependencies:\n  path: any\n',
    );

    expect(
      [for (final n in nodes) (n.name, n.line)],
      [('name', 1), ('dependencies', 3)],
    );
  });
}
