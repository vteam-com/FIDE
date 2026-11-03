import 'dart:io';

import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/services/code_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// A graph of `main` importing `home`, which imports `model`, and `main`
/// importing `model` too; [layered] gives them fCheck's layers 1 to 3.
ArchitectureGraph _graph({bool layered = true}) => ArchitectureGraph(
  rootPath: '/p',
  files: ['/p/lib/main.dart', '/p/lib/ui/home.dart', '/p/lib/core/model.dart'],
  callees: {
    '/p/lib/main.dart': ['/p/lib/ui/home.dart', '/p/lib/core/model.dart'],
    '/p/lib/ui/home.dart': ['/p/lib/core/model.dart', '/p/lib/gone.dart'],
  },
  layers: layered
      ? {
          '/p/lib/main.dart': 1,
          '/p/lib/ui/home.dart': 2,
          '/p/lib/core/model.dart': 3,
        }
      : const {},
  issues: {
    '/p/lib/ui/home.dart': ['wrong layer'],
  },
);

void main() {
  group('ArchitectureGraph', () {
    test('sorts files by folder then name, and links both ways', () {
      final graph = _graph();

      expect(graph.files, [
        '/p/lib/main.dart',
        '/p/lib/core/model.dart',
        '/p/lib/ui/home.dart',
      ]);
      expect(graph.callees['/p/lib/main.dart'], [
        '/p/lib/core/model.dart',
        '/p/lib/ui/home.dart',
      ]);
      // An import of a file outside the graph is dropped
      expect(graph.callees['/p/lib/ui/home.dart'], ['/p/lib/core/model.dart']);
      expect(graph.callers['/p/lib/core/model.dart'], [
        '/p/lib/main.dart',
        '/p/lib/ui/home.dart',
      ]);
      expect(graph.edgeCount, 3);
      expect(graph.folderOf('/p/lib/ui/home.dart'), 'lib/ui');
    });

    test('puts every file in one layer when fCheck could not layer', () {
      final graph = _graph(layered: false);

      expect(graph.isLayered, isFalse);
      expect(graph.layerNumbers, [ArchitectureGraph.unlayered]);
    });

    test('reads fCheck analysis of a project', () async {
      final project = Directory.systemTemp.createTempSync('fide_architecture_');
      addTearDown(() => project.deleteSync(recursive: true));
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
      void write(String path, String content) => File('${project.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      write('lib/main.dart', "import 'package:sample/ui/home.dart';\n");
      write('lib/ui/home.dart', "import 'package:sample/core/model.dart';\n");
      write('lib/core/model.dart', '/// A model.\nclass Model {}\n');

      final metrics = await const CodeReview().analyze(project.path);
      final graph = ArchitectureGraph.fromMetrics(metrics, project.path);
      final main = '${project.path}/lib/main.dart';
      final home = '${project.path}/lib/ui/home.dart';
      final model = '${project.path}/lib/core/model.dart';

      expect(graph.callees[main], [home]);
      expect(graph.callers[model], [home]);
      expect(graph.isLayered, isTrue);
      expect(graph.layers[main], lessThan(graph.layers[home]!));
      expect(graph.layers[home], lessThan(graph.layers[model]!));
    });
  });

  group('ArchitectureLayout', () {
    test('puts each layer in its own column, left to right', () {
      final layout = ArchitectureLayout(
        _graph(),
        orientation: ArchitectureOrientation.leftToRight,
      );
      final main = layout.nodes['/p/lib/main.dart']!;
      final home = layout.nodes['/p/lib/ui/home.dart']!;
      final model = layout.nodes['/p/lib/core/model.dart']!;

      expect(main.left, lessThan(home.left));
      expect(home.left, lessThan(model.left));
      expect(home.right, lessThan(model.left));
      expect(layout.size.width, greaterThan(model.right));
      expect(layout.size.height, greaterThan(model.bottom));
    });

    test('heads columns with layers and files with their folders', () {
      final layout = ArchitectureLayout(
        _graph(layered: false),
        orientation: ArchitectureOrientation.leftToRight,
      );
      final captions = layout.captions;

      expect(
        [for (final c in captions) c.text],
        ['Unlayered', 'lib', 'lib/core', 'lib/ui'],
      );
      expect(captions.first.isLayer, isTrue);
      expect(captions.first.detail, '3 files');
      // One column: each file below the previous one, apart
      final rects = [
        for (final file in layout.graph.files) layout.nodes[file]!,
      ];
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, rects[i - 1].left);
        expect(rects[i].top, greaterThan(rects[i - 1].bottom));
      }
    });
  });

  group('ArchitectureLayout top down', () {
    test('stacks layers as rows, top down, by default', () {
      final layout = ArchitectureLayout(_graph());
      final main = layout.nodes['/p/lib/main.dart']!;
      final home = layout.nodes['/p/lib/ui/home.dart']!;
      final model = layout.nodes['/p/lib/core/model.dart']!;

      expect(layout.orientation, ArchitectureOrientation.topDown);
      expect(main.bottom, lessThan(home.top));
      expect(home.bottom, lessThan(model.top));
      expect(main.left, home.left);
      expect(layout.size.height, greaterThan(model.bottom));
    });

    test('sets folders side by side, wrapping a big one into columns', () {
      final many = ArchitectureLayout.folderBlockRows + 1;
      final files = [
        for (var i = 0; i < many; i++) '/p/lib/big/f$i.dart',
        '/p/lib/small/s.dart',
      ];
      final layout = ArchitectureLayout(
        ArchitectureGraph(
          rootPath: '/p',
          files: files,
          callees: const {},
          layers: const {},
        ),
      );
      final first = layout.nodes['/p/lib/big/f0.dart']!;
      // Named f0 to f6: sorted by name, the seventh starts a new column
      final wrapped = layout
          .nodes['/p/lib/big/f${ArchitectureLayout.folderBlockRows}.dart']!;
      final small = layout.nodes['/p/lib/small/s.dart']!;

      // The file past the block's rows starts its second column on top
      expect(wrapped.top, first.top);
      expect(wrapped.left, greaterThan(first.right));
      // The next folder sits beside the whole block, level with it
      expect(small.left, greaterThan(wrapped.right));
      expect(small.top, first.top);
      expect(layout.size.width, greaterThan(small.right));
    });
  });

  group('ArchitectureFocus', () {
    test('marks the focused file, its callees and its callers', () {
      final focus = ArchitectureFocus(_graph(), file: '/p/lib/ui/home.dart');

      expect(focus.roleOf('/p/lib/ui/home.dart'), ArchitectureRole.focused);
      expect(focus.roleOf('/p/lib/core/model.dart'), ArchitectureRole.callee);
      expect(focus.roleOf('/p/lib/main.dart'), ArchitectureRole.caller);
      expect(
        focus.isHighlighted('/p/lib/main.dart', '/p/lib/ui/home.dart'),
        isTrue,
      );
      expect(
        focus.isHighlighted('/p/lib/main.dart', '/p/lib/core/model.dart'),
        isFalse,
      );
    });

    test('finds files as Go to File does, best match first', () {
      // Letters in order, not a substring: m-d-l only spells model.dart
      final focus = ArchitectureFocus(_graph(), query: 'mdl');

      expect(focus.matches, ['/p/lib/core/model.dart']);
      expect(focus.isMatch('/p/lib/core/model.dart'), isTrue);
      expect(focus.isMatch('/p/lib/main.dart'), isFalse);
    });

    test('without a focused file, dims the files the query misses', () {
      final focus = ArchitectureFocus(_graph(), query: 'UI/');

      expect(focus.matches, ['/p/lib/ui/home.dart']);
      expect(focus.roleOf('/p/lib/ui/home.dart'), ArchitectureRole.plain);
      expect(focus.roleOf('/p/lib/main.dart'), ArchitectureRole.dimmed);
      expect(
        ArchitectureFocus(_graph()).roleOf('/p/lib/main.dart'),
        ArchitectureRole.plain,
      );
    });
  });
}
