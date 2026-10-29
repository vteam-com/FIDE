import 'dart:io';

import 'package:fide/models/code_category.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/project_categorizer.dart';
import 'package:fide/providers/project_tree_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('fide_categ_'));
  tearDown(() => project.deleteSync(recursive: true));

  void write(String relativePath, String content) {
    File(p.join(project.path, relativePath))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  Future<ProjectNode> loadedRoot() async {
    final root = ProjectNode(
      name: p.basename(project.path),
      path: project.path,
      type: ProjectNodeType.directory,
    );
    await const ProjectTreeReader().loadTree(root);
    return root;
  }

  List<String> names(List<ProjectNode> nodes) => [
    for (final node in nodes) node.name,
  ];

  test('sorts files by folder and by content', () async {
    write('lib/models/user.dart', 'class User {}');
    write('lib/main.dart', 'void main() => runApp(MaterialApp());');
    write('lib/card.dart', 'class Card extends StatelessWidget {}');
    write('lib/util.dart', 'int add(int a, int b) => a + b;');

    final categories = await const ProjectCategorizer().categorize(
      await loadedRoot(),
    );

    expect(names(categories.nodes[CodeCategory.models]!), ['user.dart']);
    expect(names(categories.nodes[CodeCategory.views]!), ['main.dart']);
    expect(names(categories.nodes[CodeCategory.widgets]!), ['card.dart']);
    expect(categories.elementCounts[CodeCategory.models], 1);
  });

  test('moves showDialog callers to dialogs, but only flags views', () async {
    write('lib/widgets/picker.dart', 'void f() { showDialog(); }');
    write('lib/screens/home.dart', 'void g() { showDialog(); }');

    final categories = await const ProjectCategorizer().categorize(
      await loadedRoot(),
    );

    expect(names(categories.nodes[CodeCategory.dialogs]!), ['picker.dart']);
    expect(categories.nodes[CodeCategory.widgets], isEmpty);
    expect(names(categories.nodes[CodeCategory.views]!), ['home.dart']);
    expect(categories.viewsWithDialogs, {
      p.join(project.path, 'lib', 'screens', 'home.dart'),
    });
  });

  test('counts classes per Dart file, at least one each', () async {
    write('lib/models/chord.dart', 'class Chord {}\n\nclass  FooBar{}');
    write('lib/models/base.dart', 'abstract class Base {}');
    write('lib/models/helpers.dart', 'int add(int a, int b) => a + b;');

    final categories = await const ProjectCategorizer().categorize(
      await loadedRoot(),
    );

    expect(categories.sourceFileCounts[CodeCategory.models], 3);
    expect(categories.elementCounts[CodeCategory.models], 4);
  });

  test('counts translations in ARB files', () async {
    write('lib/l10n/app_en.arb', '{"@@locale": "en", "a": "A", "b": "B"}');

    final categories = await const ProjectCategorizer().categorize(
      await loadedRoot(),
    );

    expect(categories.elementCounts[CodeCategory.localization], 2);
  });
}
