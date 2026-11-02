import 'dart:io';

import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/right/outline_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('re-outlines the file as its editor text changes', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('outline_panel_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final path = '${folder.path}/notes.md';
    File(path).writeAsStringSync('# First\n');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(path),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: OutlinePanel(file: FileSystemItem.fromPath(path)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);

    container
        .read(openDocumentsProvider.notifier)
        .update(path, content: '# First\n## Second\n');
    // Past the outline's debounce
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Second'), findsOneWidget);
  });
}
