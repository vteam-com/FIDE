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

  test('Dart outlines mark @override methods', () {
    final nodes = const DartOutlineParser().parse(
      'class A {\n  @override\n  String toString() => "";\n  void run() {}\n}\n',
    );

    expect([for (final n in nodes) n.isOverride], [false, true, false]);
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
