import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/services/editor_commands.dart';
import 'package:fide/widget_services/search_result_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// An editor recording where it is asked to move the caret.
class _RecordingEditor implements EditorCommands {
  /// Each 1-based line and column asked, in order.
  final List<(int, int)> moves = [];

  @override
  void navigateToLine(int lineNumber, {int column = 1}) =>
      moves.add((lineNumber, column));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a place opens with the caret on the name it marks, as Go to '
      'Definition does', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = _RecordingEditor();
    container.read(activeEditorProvider).attach(editor);
    const place = SearchResult(
      filePath: '/project/lib/shapes.dart',
      lineNumber: 6,
      lineContent: '  void draw() {}',
      matchStart: 7,
      matchEnd: 11,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SearchResultRow(result: place)),
        ),
      ),
    );

    await tester.tap(find.byType(SearchResultRow));
    await tester.pump(AppDuration.editorScroll);

    expect(editor.moves, [(6, 8)]);
  });
}
