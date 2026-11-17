import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/folder_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/filename_widget.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Folders in the project, each holding [_filesPerFolder] files.
const int _folderCount = 20;

/// Files in each folder.
const int _filesPerFolder = 50;

/// A loaded project of [_folderCount] folders of [_filesPerFolder] files.
ProjectNode _project() => ProjectNode(
  name: 'p',
  path: '/p',
  type: ProjectNodeType.directory,
  children: [
    for (var folder = 0; folder < _folderCount; folder++)
      ProjectNode(
        name: 'dir$folder',
        path: '/p/dir$folder',
        type: ProjectNodeType.directory,
        children: [
          for (var file = 0; file < _filesPerFolder; file++)
            ProjectNode(
              name: 'file${folder}_$file.dart',
              path: '/p/dir$folder/file${folder}_$file.dart',
              type: ProjectNodeType.file,
            ),
        ],
      ),
  ],
);

/// Shows the Explorer of [_project], returning its provider container.
Future<ProviderContainer> _pumpExplorer(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProjectRootProvider.overrideWith((_) => _project()),
        projectLoadedProvider.overrideWith((_) => true),
      ],
      child: const MaterialApp(home: Scaffold(body: FolderPanel())),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(FolderPanel)));
}

void main() {
  testWidgets('a filter matching every file builds only the rows on screen', (
    tester,
  ) async {
    await _pumpExplorer(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(FilterField),
        matching: find.byType(TextField),
      ),
      'file',
    );
    await tester.pump();

    final built = find.byType(FileNameWidget).evaluate().length;
    expect(built, greaterThan(0));
    // A screenful of the 1,000 matching files
    expect(built, lessThan(_folderCount * _filesPerFolder ~/ 10));
    expect(find.text('dir0'), findsOneWidget);
  });

  testWidgets('revealing a file far down scrolls its row into view', (
    tester,
  ) async {
    final container = await _pumpExplorer(tester);
    const target = '/p/dir15/file15_40.dart';

    // Every folder open, the last first while each is on screen, so the
    // target is far below the screen
    for (var folder = _folderCount - 1; folder >= 0; folder--) {
      await tester.tap(find.text('dir$folder'));
      await tester.pump();
    }
    container.read(explorerRevealPathProvider.notifier).state = target;
    await tester.pumpAndSettle();

    expect(find.text('file15_40.dart'), findsOneWidget);
    final row = tester.getRect(find.text('file15_40.dart'));
    final screen = tester.getRect(find.byType(FolderPanel));
    expect(screen.contains(row.center), isTrue);
  });
}
