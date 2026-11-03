import 'dart:io';

import 'package:fide/models/outline_kind.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/outline_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/outline_parser.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Finds one consumer of everything and renames by rewriting the file.
class _FakeFinder extends ReferenceFinder {
  _FakeFinder()
    : super(projectPath: '', flutterSdk: const FlutterSdk(ProcessRunner()));

  int finds = 0;

  bool fail = false;

  @override
  Future<List<SearchResult>> find({
    required String filePath,
    required int line,
    required int column,
  }) async {
    finds++;
    if (fail) throw StateError('cannot analyze');
    return [
      SearchResult(
        filePath: filePath,
        lineNumber: line,
        lineContent: 'use',
        matchStart: 0,
        matchEnd: 1,
      ),
    ];
  }

  @override
  Future<Map<String, String>> rename({
    required String filePath,
    required int line,
    required int column,
    required String newName,
  }) async => {filePath: 'class $newName {}\n'};
}

/// Past the outline's debounce.
Future<void> _settle() => Future<void>.delayed(OutlineController.debounce * 2);

void main() {
  late Directory folder;
  late String path;
  late _FakeFinder finder;
  late ProviderContainer container;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('outline_controller_');
    path = p.join(folder.path, 'a.dart');
    File(path).writeAsStringSync('class A {\n  void run() {}\n}\n');
    finder = _FakeFinder();
    container = ProviderContainer(
      overrides: [referenceFinderProvider.overrideWithValue(finder)],
    );
    // Keeps the auto-disposed controller alive
    container.listen(outlineControllerProvider(path), (_, _) {});
  });

  tearDown(() {
    container.dispose();
    folder.deleteSync(recursive: true);
  });

  OutlineState outline() => container.read(outlineControllerProvider(path));

  OutlineController controller() =>
      container.read(outlineControllerProvider(path).notifier);

  test('outlines the saved file, then the editor text as it changes', () async {
    expect(outline().isLoading, isTrue);
    await _settle();

    expect([for (final n in outline().nodes) n.name], ['A', 'run']);
    expect(outline().isLoading, isFalse);

    await container.read(openDocumentsProvider.notifier).open(path);
    container
        .read(openDocumentsProvider.notifier)
        .update(path, content: 'class B {}\n');
    await _settle();

    expect([for (final n in outline().nodes) n.name], ['B']);
  });

  test('a file type without an outline has no entries', () async {
    final json = p.join(folder.path, 'a.json');
    container.listen(outlineControllerProvider(json), (_, _) {});
    await _settle();

    final state = container.read(outlineControllerProvider(json));
    expect(state.nodes, isEmpty);
    expect(state.isLoading, isFalse);
  });

  test('reports a parse error and parses again on demand', () async {
    final yaml = p.join(folder.path, 'a.yaml');
    File(yaml).writeAsStringSync('a: [\n');
    container.listen(outlineControllerProvider(yaml), (_, _) {});
    await _settle();
    expect(
      container.read(outlineControllerProvider(yaml)).error,
      startsWith('Error parsing file'),
    );

    File(yaml).writeAsStringSync('a: 1\n');
    await container.read(outlineControllerProvider(yaml).notifier).parse();

    final state = container.read(outlineControllerProvider(yaml));
    expect(state.error, isEmpty);
    expect(state.nodes, hasLength(1));
  });

  test(
    'the cursor highlights the entry under it and counts its consumers',
    () async {
      await _settle();

      container.read(editorCursorLineProvider.notifier).state = 2;
      await _settle();

      final run = outline().nodes.last;
      expect(outline().isHighlighted(run), isTrue);
      expect(outline().isHighlighted(outline().nodes.first), isTrue);
      expect(outline().isCounted(run), isTrue);
      expect(outline().consumersOf(run), hasLength(1));
      expect(outline().consumersOf(outline().nodes.first), isNull);

      // The same entry is not looked up again
      controller().setCursorLine(2);
      expect(finder.finds, 1);

      finder.fail = true;
      controller().setCursorLine(1);
      await _settle();
      expect(outline().countedNode, isNull);
    },
  );

  test('rename rewrites the project and reports the files', () async {
    await _settle();
    await container.read(openDocumentsProvider.notifier).open(path);

    expect(controller().canRename, isTrue);
    final files = await controller().rename(outline().nodes.first, 'B');
    await _settle();

    expect(files.keys, [path]);
    expect(File(path).readAsStringSync(), 'class B {}\n');
    expect(outline().isRenaming, isFalse);
    expect([for (final n in outline().nodes) n.name], ['B']);
  });

  test('rename needs an open project', () async {
    final closed = ProviderContainer(
      overrides: [referenceFinderProvider.overrideWithValue(null)],
    );
    addTearDown(closed.dispose);
    closed.listen(outlineControllerProvider(path), (_, _) {});
    final controller = closed.read(outlineControllerProvider(path).notifier);

    expect(controller.canRename, isFalse);
    await expectLater(
      controller.rename(
        const OutlineNode(name: 'A', kind: OutlineKind.dartClass, line: 1),
        'B',
      ),
      throwsStateError,
    );
  });

  test('the parser provider picks a parser by file type', () {
    expect(
      container.read(outlineParserProvider('x.md')),
      isA<MarkdownOutlineParser>(),
    );
    expect(container.read(outlineParserProvider('x.txt')), isNull);
  });

  group('OutlineState', () {
    const a = OutlineNode(name: 'A', kind: OutlineKind.dartClass, line: 1);
    const run = OutlineNode(
      name: 'run',
      kind: OutlineKind.method,
      line: 2,
      level: 1,
    );
    const b = OutlineNode(name: 'B', kind: OutlineKind.dartClass, line: 5);

    test('selects the innermost entry under the cursor', () {
      const state = OutlineState(nodes: [a, run, b], cursorLine: 3);

      expect(state.selected, run);
      expect(const OutlineState(nodes: [a, run, b]).selected, isNull);
    });

    test('copyWith replaces the counted entry and its consumers', () {
      final counted = const OutlineState().copyWith(
        counted: (node: a),
        found: (uses: const <SearchResult>[]),
      );

      expect(counted.isCounted(a), isTrue);
      expect(counted.consumersOf(a), isEmpty);
      expect(counted.copyWith(counted: (node: null)).countedNode, isNull);
      expect(counted.copyWith(isRenaming: true).consumers, isEmpty);
    });
  });

  group('OutlineNode', () {
    const a = OutlineNode(name: 'A', kind: OutlineKind.dartClass, line: 1);
    const run = OutlineNode(
      name: 'run',
      kind: OutlineKind.method,
      line: 2,
      level: 1,
    );
    const b = OutlineNode(name: 'B', kind: OutlineKind.dartClass, line: 5);
    const outline = [a, run, b];

    test('coversLine spans an entry to the next one as deep or less', () {
      expect(a.coversLine(1, outline), isTrue);
      expect(a.coversLine(4, outline), isTrue);
      expect(a.coversLine(5, outline), isFalse);
      expect(run.coversLine(3, outline), isTrue);
      expect(run.coversLine(4, outline), isTrue);
      // The last entry runs to the end
      expect(b.coversLine(100, outline), isTrue);
      expect(b.coversLine(4, outline), isFalse);
      expect(b.coversLine(4, [a]), isFalse);
    });

    test(
      'isSameAs matches across re-parses, usedName drops type arguments',
      () {
        const again = OutlineNode(
          name: 'A',
          kind: OutlineKind.dartClass,
          line: 1,
        );

        expect(a.isSameAs(again), isTrue);
        expect(a.isSameAs(b), isFalse);
        expect(a.isSameAs(null), isFalse);
        expect(
          const OutlineNode(
            name: 'Box<T>',
            kind: OutlineKind.dartClass,
            line: 1,
          ).usedName,
          'Box',
        );
      },
    );
  });
}
