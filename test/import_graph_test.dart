import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/import_graph.dart';
import 'package:flutter_test/flutter_test.dart';

/// A widget in a panels folder using a helper there, and a panel using
/// the widget.
const ImportGraph _panels = ImportGraph({
  'lib/panels/a.dart': {'lib/panels/helper.dart'},
  'lib/panels/helper.dart': {},
  'lib/panels/panel.dart': {'lib/panels/a.dart'},
});

void main() {
  test('reads imports, exports, parts and conditional URIs naming project '
      'files, by package or relative URI', () {
    final graph = ImportGraph.parse({
      'lib/a.dart':
          "import 'package:flutter/material.dart';\n"
          "import 'package:demo/b.dart';\n"
          "export 'c.dart';\n"
          "import 'd.dart' if (dart.library.io) 'e.dart';\n"
          "part 'a.g.dart';\n",
    }, packageName: 'demo');

    expect(graph.edges['lib/a.dart'], {
      'lib/b.dart',
      'lib/c.dart',
      'lib/d.dart',
      'lib/e.dart',
      'lib/a.g.dart',
    });
  });

  test('fCheck judges the graph: files importing each other are an '
      'issue', () {
    final before = ImportGraph.parse({
      'lib/a.dart': "import 'b.dart';\n",
      'lib/b.dart': '',
    });

    final after = before.updated({'lib/b.dart': "import 'a.dart';\n"});
    final (:added, :fixed) = ImportGraph.compareIssues(
      before.layerIssues,
      after.layerIssues,
    );

    expect(before.layerIssues, isEmpty);
    expect(
      added.map((issue) => issue.type),
      contains(fcheck.LayersIssueType.cyclicDependency),
    );
    expect(fixed, isEmpty);
  });

  test('a move making two folders depend on each other adds an issue '
      'naming them; moving the helper along adds none', () {
    const moves = {'lib/panels/a.dart': 'lib/widgets/a.dart'};

    final (:added, fixed: _) = ImportGraph.compareIssues(
      _panels.layerIssues,
      _panels.moved(moves).layerIssues,
      moves: moves,
    );

    expect(added, isNotEmpty);
    expect({
      for (final issue in added) ...ImportGraph.foldersOf(issue),
    }, containsAll(['lib/panels']));
    const along = {
      ...moves,
      'lib/panels/helper.dart': 'lib/widgets/helper.dart',
    };
    expect(
      ImportGraph.compareIssues(
        _panels.layerIssues,
        _panels.moved(along).layerIssues,
        moves: along,
      ).added,
      isEmpty,
    );
  });

  test('an issue a move leaves as it was is no news; one it removes is '
      'fixed', () {
    const before = ImportGraph({
      'lib/a/x.dart': {'lib/b/y.dart'},
      'lib/b/y.dart': {'lib/a/z.dart'},
      'lib/a/z.dart': {},
    });
    const moves = {'lib/a/z.dart': 'lib/c/z.dart'};

    final (:added, :fixed) = ImportGraph.compareIssues(
      before.layerIssues,
      before.moved(moves).layerIssues,
      moves: moves,
    );

    expect(added, isEmpty);
    expect(
      fixed.map((issue) => issue.type),
      contains(fcheck.LayersIssueType.folderCycle),
    );
  });

  test('a file at the project root belongs to no folder', () {
    expect(ImportGraph.folderOf('main.dart'), isNull);
    expect(ImportGraph.folderOf('lib/main.dart'), 'lib');
  });
}
