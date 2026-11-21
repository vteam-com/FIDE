import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/core_constants.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/panels/center/editor/editor_screen.dart';
import 'package:fide/panels/center/editor/editor_screen_header.dart';
import 'package:fide/panels/center/editor/editor_screen_status_bar.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory folder;
  late String path;
  late ProviderContainer container;

  setUp(() {
    // The editor reads the saved View as Markdown choice
    SharedPreferences.setMockInitialValues({});
    folder = Directory.systemTemp.createTempSync('editor_rebuilds_');
    path = '${folder.path}/notes.md';
    File(path).writeAsStringSync('# Title\n\nSome text\n');
    container = ProviderContainer(
      overrides: [
        // No git: the header shows no change counts
        gitDiffStatsProvider.overrideWith((_, _) async => null),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    folder.deleteSync(recursive: true);
  });

  /// Shows the center panel with [path] open in the editor.
  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(path),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CenterPanel(terminalVisible: false)),
        ),
      ),
    );
    // The editor loads its icon fonts from the assets for real, then
    // relayouts for them
    await tester.runAsync(
      () => Future<void>.delayed(AppDuration.updateDebounce),
    );
    await tester.pump();
  }

  CodeForgeController code(WidgetTester tester) =>
      tester.widget<CodeForge>(find.byType(CodeForge)).controller!;

  testWidgets('typing rebuilds neither the center panel nor the header', (
    tester,
  ) async {
    await pumpEditor(tester);

    // The first edit marks the file unsaved, which the header shows
    code(tester).text = '# Title\n\nSome text!\n';
    await tester.pump();
    final screen = tester.widget(find.byType(EditorScreen));
    final header = tester.widget(find.byType(EditorScreenHeader));

    code(tester).text = '# Title\n\nSome text!!\n';
    await tester.pump();

    expect(
      container.read(activeDocumentProvider)!.content,
      '# Title\n\nSome text!!\n',
    );
    // A rebuild would have created new widgets
    expect(tester.widget(find.byType(EditorScreen)), same(screen));
    expect(tester.widget(find.byType(EditorScreenHeader)), same(header));
  });

  testWidgets('a caret move publishes nothing and updates the status bar', (
    tester,
  ) async {
    await pumpEditor(tester);
    final states = <Object>[];
    container.listen(openDocumentsProvider, (_, next) => states.add(next));
    final header = tester.widget(find.byType(EditorScreenHeader));

    code(tester).selection = const TextSelection.collapsed(offset: 11);
    await tester.pump();

    expect(states, isEmpty);
    expect(tester.widget(find.byType(EditorScreenHeader)), same(header));
    final statusBar = tester.widget<EditorScreenStatusBar>(
      find.byType(EditorScreenStatusBar),
    );
    expect(
      (statusBar.currentLineNumber, statusBar.currentColumnNumber),
      (3, 3),
    );
    expect(container.read(editorCursorLineProvider), 3);
  });

  testWidgets('the caret is restored after showing another file', (
    tester,
  ) async {
    final other = '${folder.path}/other.md';
    File(other).writeAsStringSync('# Other\n');
    await pumpEditor(tester);
    code(tester).selection = const TextSelection.collapsed(offset: 11);
    await tester.pump();

    final documents = container.read(openDocumentsProvider.notifier);
    await tester.runAsync(() => documents.open(other));
    await tester.pump();
    documents.activate(0);
    await tester.pump();
    await tester.pump();

    expect(code(tester).text, '# Title\n\nSome text\n');
    expect(code(tester).selection, const TextSelection.collapsed(offset: 11));
  });
}
