import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/core_constants.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/panels/center/editor/editor_screen_markdown_view.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/providers/markdown_preview_notifier.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory folder;
  late String path;
  late ProviderContainer container;

  /// The header's toggle between the Markdown text and its rendering.
  final toggle = find.byKey(const Key('keyEditorMarkdown'));

  setUp(() {
    // The toggle saves its choice
    SharedPreferences.setMockInitialValues({});
    folder = Directory.systemTemp.createTempSync('editor_markdown_');
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

  /// Lets the fonts a view loads for real arrive, then relayouts for them.
  Future<void> settleFonts(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(AppDuration.updateDebounce),
    );
    await tester.pump();
  }

  /// Taps the header's Markdown toggle and lets the view it shows settle.
  Future<void> tapToggle(WidgetTester tester) async {
    await tester.tap(toggle);
    await tester.pump();
    await settleFonts(tester);
  }

  /// Shows the center panel with [filePath] open in the editor.
  Future<void> pumpEditor(WidgetTester tester, String filePath) async {
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(filePath),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CenterPanel(terminalVisible: false)),
        ),
      ),
    );
    // The editor loads its icon fonts from the assets
    await settleFonts(tester);
  }

  /// Opens [filePath] as another tab and shows it.
  Future<void> openOther(WidgetTester tester, String filePath) async {
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(filePath),
    );
    await tester.pump();
    await settleFonts(tester);
  }

  testWidgets('the toggle shows the Markdown rendered, then its text', (
    tester,
  ) async {
    await pumpEditor(tester, path);
    expect(find.byType(CodeForge), findsOneWidget);
    expect(find.byType(EditorScreenMarkdownView), findsNothing);

    await tapToggle(tester);

    expect(find.byType(CodeForge), findsNothing);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(container.read(markdownPreviewProvider), isTrue);

    await tapToggle(tester);

    expect(find.byType(EditorScreenMarkdownView), findsNothing);
    expect(find.byType(CodeForge), findsOneWidget);
    expect(container.read(markdownPreviewProvider), isFalse);
  });

  testWidgets('the choice holds for every Markdown file opened', (
    tester,
  ) async {
    final other = '${folder.path}/other.md';
    File(other).writeAsStringSync('# Other\n');
    await pumpEditor(tester, path);
    await tapToggle(tester);

    await openOther(tester, other);
    expect(find.byType(EditorScreenMarkdownView), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    await tapToggle(tester);
    container.read(openDocumentsProvider.notifier).activate(0);
    await tester.pump();
    await settleFonts(tester);
    expect(find.byType(CodeForge), findsOneWidget);
  });

  testWidgets('files other than Markdown show their text, with no toggle', (
    tester,
  ) async {
    await container.read(markdownPreviewProvider.notifier).setPreview(true);
    final text = '${folder.path}/notes.txt';
    File(text).writeAsStringSync('# Not Markdown\n');
    await pumpEditor(tester, text);

    expect(toggle, findsNothing);
    expect(find.byType(CodeForge), findsOneWidget);
  });

  testWidgets('going to a line shows that file\'s text only', (tester) async {
    final other = '${folder.path}/other.md';
    File(other).writeAsStringSync('# Other\n');
    await pumpEditor(tester, path);
    await tapToggle(tester);

    container.read(activeEditorProvider).navigateToLine(3);
    await tester.pump();
    await settleFonts(tester);

    expect(find.byType(CodeForge), findsOneWidget);
    expect(container.read(markdownPreviewProvider), isTrue);

    await openOther(tester, other);
    expect(find.byType(EditorScreenMarkdownView), findsOneWidget);
  });
}
