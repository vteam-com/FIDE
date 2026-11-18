import 'dart:io';

import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/file_outline.dart';
import 'package:fide/widget_services/file_tree_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory folder;
  late String path;
  late ProviderContainer container;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('file_outline_');
    path = '${folder.path}/notes.md';
    File(path).writeAsStringSync('# First\n');
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    folder.deleteSync(recursive: true);
  });

  /// Opens the notes in the editor, then shows [child].
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(path),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('re-outlines the file as its editor text changes', (
    tester,
  ) async {
    await pump(tester, FileOutline(path: path));
    expect(find.text('First'), findsOneWidget);

    container
        .read(openDocumentsProvider.notifier)
        .update(path, content: '# First\n## Second\n');
    // Past the outline's debounce
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('shows nothing while its file row folds it', (tester) async {
    await pump(tester, FileOutline(path: path));

    container.read(foldedOutlinePathProvider.notifier).state = path;
    await tester.pump();
    expect(find.text('First'), findsNothing);

    container.read(foldedOutlinePathProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
  });

  testWidgets('a file row shows its outline only while selected', (
    tester,
  ) async {
    await pump(tester, FileTreeRow(fileItem: FileSystemItem.fromPath(path)));
    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('First'), findsNothing);

    container.read(selectedFileProvider.notifier).state =
        FileSystemItem.fromPath(path);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
  });
}
