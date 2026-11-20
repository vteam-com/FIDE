import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// A finder answering each definition lookup with [answer], recording
/// what it was asked.
class _FakeFinder extends ReferenceFinder {
  _FakeFinder(this.answer)
    : super(projectPath: '/project', dartSdkPath: () async => '/sdk');

  /// The place to answer with, or the error to throw.
  Object answer;

  /// The caret offset and text of each lookup asked.
  final List<(int, String)> asked = [];

  @override
  Future<SearchResult> definition({
    required String filePath,
    required int offset,
    required String content,
  }) async {
    asked.add((offset, content));
    return switch (answer) {
      final SearchResult place => place,
      final error => throw error,
    };
  }
}

void main() {
  late Directory folder;
  late ProviderContainer container;
  late _FakeFinder finder;
  late String code;
  late String target;

  const content = 'final value = answer();\n';

  setUp(() {
    folder = Directory.systemTemp.createTempSync('editor_definition_');
    code = p.join(folder.path, 'code.dart');
    File(code).writeAsStringSync(content);
    target = p.join(folder.path, 'answer.dart');
    File(target).writeAsStringSync('int answer() => 42;\n');
    finder = _FakeFinder(
      SearchResult(
        filePath: target,
        lineNumber: 1,
        lineContent: 'int answer() => 42;',
        matchStart: 4,
        matchEnd: 10,
      ),
    );
    container = ProviderContainer(
      overrides: [
        // No git: the header shows no change counts
        gitDiffStatsProvider.overrideWith((_, _) async => null),
        referenceFinderProvider.overrideWithValue(finder),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    folder.deleteSync(recursive: true);
  });

  /// Shows the center panel with [code] open in the editor.
  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(code),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CenterPanel(terminalVisible: false)),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(AppDuration.updateDebounce),
    );
    await tester.pump();
  }

  /// The editor's text and caret.
  CodeForgeController controller(WidgetTester tester) =>
      tester.widget<CodeForge>(find.byType(CodeForge)).controller!;

  /// Sends Edit › Go to Definition (F12) to the editor and lets it open
  /// the place found.
  Future<void> goToDefinition(WidgetTester tester) async {
    await tester.runAsync(
      () => container.read(activeEditorProvider).goToDefinition(),
    );
    await tester.pump();
  }

  testWidgets('Go to Definition looks up the name at the caret, unsaved '
      'edits included, and opens where it is declared', (tester) async {
    await pumpEditor(tester);
    final editor = controller(tester);
    const edited = '// unsaved\n$content';
    editor.text = edited;
    final caret = edited.indexOf('answer');
    editor.selection = TextSelection.collapsed(offset: caret);
    await tester.pump();

    await goToDefinition(tester);

    expect(finder.asked, [(caret, edited)]);
    expect(container.read(selectedFileProvider)?.path, target);
  });

  testWidgets('Go to Definition says why it found nowhere to go, but not '
      'for a lookup a newer one replaced', (tester) async {
    await pumpEditor(tester);

    finder.answer = Exception(
      'Bad state: print is declared outside the project, in dart:core',
    );
    await goToDefinition(tester);
    expect(
      find.text('print is declared outside the project, in dart:core'),
      findsOneWidget,
    );

    finder.answer = Exception(ReferenceFinder.superseded);
    await goToDefinition(tester);
    expect(find.text(ReferenceFinder.superseded), findsNothing);
    expect(container.read(selectedFileProvider), isNull);
  });

  testWidgets(
    'a click with the platform\'s command key goes to the definition, a '
    'plain click doesn\'t',
    (tester) async {
      await pumpEditor(tester);
      final key = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      await tester.tap(find.byType(CodeForge));
      await tester.pump();
      expect(finder.asked, isEmpty);

      await tester.sendKeyDownEvent(key);
      await tester.tap(find.byType(CodeForge));
      await tester.sendKeyUpEvent(key);
      // The place found opens once the editor has shown its file
      await tester.pump(AppDuration.editorScroll);

      expect(finder.asked, hasLength(1));
      expect(container.read(selectedFileProvider)?.path, target);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );
}
