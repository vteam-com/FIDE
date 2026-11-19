import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/panels/right/symbol_info_section.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Finds one caller of everything, and [calls] as what it calls.
class _FakeFinder extends ReferenceFinder {
  _FakeFinder(this.calls)
    : super(
        projectPath: '',
        dartSdkPath: () async => throw const FlutterSdkNotFoundException(),
      );

  final List<SearchResult> calls;

  @override
  Future<List<SearchResult>> find({
    required String filePath,
    required int line,
    required int column,
  }) async => [_place('/p/lib/home.dart', 'a.run();', 'run')];

  @override
  Future<List<SearchResult>> callees({
    required String filePath,
    required int line,
    required int column,
  }) async => calls;
}

/// The line [content] of [path], marking [name] in it.
SearchResult _place(String path, String content, String name) {
  final start = content.indexOf(name);
  return SearchResult(
    filePath: path,
    lineNumber: 1,
    lineContent: content,
    matchStart: start,
    matchEnd: start + name.length,
  );
}

void main() {
  late Directory folder;
  late String path;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('symbol_info_');
    path = '${folder.path}/a.dart';
    File(path)
        .writeAsStringSync('class A {\n  void run() {}\n}\n\nclass B {}\n');
  });

  tearDown(() => folder.deleteSync(recursive: true));

  /// Shows the section about what the cursor, on [line] of the file, is
  /// in, the finder answering [calls]; returns its provider container.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    int line, {
    List<SearchResult> calls = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        referenceFinderProvider.overrideWithValue(_FakeFinder(calls)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(path),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (_, ref, _) {
                  final node = ref
                      .watch(outlineControllerProvider(path))
                      .selected;
                  return node == null
                      ? const SizedBox()
                      : SymbolInfoSection(path: path, node: node);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    container.read(editorCursorLineProvider.notifier).state = line;
    // Past the debounce of the callers lookup
    await tester.pumpAndSettle(AppDuration.updateDebounce * 2);
    return container;
  }

  testWidgets('a method lists its callers and calls, named with its '
      'class', (tester) async {
    await pump(
      tester,
      2,
      calls: [_place('/p/lib/b.dart', 'void helper() {}', 'helper')],
    );

    expect(find.text('A.run'), findsOneWidget);
    expect(find.text('Callers'), findsOneWidget);
    expect(find.text('a.run();'), findsOneWidget);
    expect(find.text('Calls'), findsOneWidget);
    expect(find.text('void helper() {}'), findsOneWidget);
  });

  testWidgets('a method calling nothing of the project says so', (
    tester,
  ) async {
    await pump(tester, 2);

    expect(find.text('Calls nothing the project declares'), findsOneWidget);
  });

  testWidgets('a class lists its callers only', (tester) async {
    await pump(tester, 5);

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Callers'), findsOneWidget);
    expect(find.text('Calls'), findsNothing);
  });
}
