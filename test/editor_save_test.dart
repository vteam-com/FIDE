import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/core_constants.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory folder;
  late ProviderContainer container;

  setUp(() {
    // The editor reads the saved View as Markdown choice
    SharedPreferences.setMockInitialValues({});
    folder = Directory.systemTemp.createTempSync('editor_save_');
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
  Future<void> pumpEditor(WidgetTester tester, String path) async {
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
    await tester.runAsync(
      () => Future<void>.delayed(AppDuration.updateDebounce),
    );
    await tester.pump();
  }

  /// Sends File › Save (⌘S) to the editor.
  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() => container.read(activeEditorProvider).save());
    await tester.pump();
  }

  testWidgets('Save leaves a media file it did not change alone', (
    tester,
  ) async {
    final path = '${folder.path}/logo.png';
    final bytes = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3];
    File(path).writeAsBytesSync(bytes);
    await pumpEditor(tester, path);

    await save(tester);

    expect(File(path).readAsBytesSync(), bytes);
  });

  testWidgets('Save writes the edited code', (tester) async {
    final path = '${folder.path}/notes.md';
    File(path).writeAsStringSync('# Title\n');
    await pumpEditor(tester, path);
    tester.widget<CodeForge>(find.byType(CodeForge)).controller!.text =
        '# Title!\n';
    await tester.pump();

    await save(tester);

    expect(File(path).readAsStringSync(), '# Title!\n');
    expect(find.text('Saved notes.md'), findsOneWidget);
  });
}
