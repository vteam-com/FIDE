import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// How long each wait for the background diff lasts.
const Duration _waitStep = Duration(milliseconds: 50);

/// Most waits for the background diff before the test gives up.
const int _maxWaits = 200;

/// [lines] as comparable records.
List<(String, String, String, String, DiffType)> _rows(List<DiffLine> lines) =>
    [
      for (final l in lines)
        (l.oldLine, l.oldContent, l.newLine, l.newContent, l.type),
    ];

/// [count] distinct lines starting with [prefix], joined.
String _text(String prefix, int count) =>
    [for (var i = 0; i < count; i++) '$prefix$i'].join('\n');

void main() {
  test('encodes lines past the UTF-16 surrogates', () {
    const count = 60000;
    const changed = 58000;
    final oldText = _text('line ', count);
    final newText = oldText.replaceFirst('line $changed\n', 'edited\n');

    final lines = SideBySideDiff.computeLines(oldText, newText);

    expect(lines, hasLength(count + 1));
    expect(lines[changed].type, DiffType.deletion);
    expect(lines[changed].oldContent, 'line $changed');
    expect(lines[changed + 1].type, DiffType.addition);
    expect(lines[changed + 1].newContent, 'edited');
    expect(lines.last.newContent, 'line ${count - 1}');
  });

  test('shows every line replaced past the lines it can encode', () {
    const count = 35000;
    final lines = SideBySideDiff.computeLines(
      _text('old ', count),
      _text('new ', count),
    );

    expect(lines.take(count).every((l) => l.type == DiffType.deletion), true);
    expect(lines.skip(count).every((l) => l.type == DiffType.addition), true);
    expect(lines.last.newLine, '$count');
  });

  test('diffs in the background as it does inline', () async {
    const oldText = 'a\nb\nc\nd\ne';
    const newText = 'a\nB\nc\nd\nE\nF';

    expect(
      _rows(await SideBySideDiff.computeLinesInBackground(oldText, newText)),
      _rows(SideBySideDiff.computeLines(oldText, newText)),
    );
  });

  testWidgets('waits for long texts diffed in the background', (tester) async {
    final oldText = _text('line ', SideBySideDiff.maxInlineDiffLength);
    final newText = '$oldText\nadded';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SideBySideDiff(oldText: oldText, newText: newText),
        ),
      ),
    );
    expect(find.byType(LoadingIndicator), findsOneWidget);
    expect(find.text('line 0'), findsNothing);

    for (var i = 0; i < _maxWaits; i++) {
      await tester.runAsync(() => Future<void>.delayed(_waitStep));
      await tester.pump();
      if (find.byType(LoadingIndicator).evaluate().isEmpty) break;
    }

    expect(find.byType(LoadingIndicator), findsNothing);
    expect(find.text('line 0'), findsNWidgets(2));
    expect(find.text('1 change'), findsOneWidget);
  });

  testWidgets('diffs short texts right away', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SideBySideDiff(oldText: 'a', newText: 'b'),
        ),
      ),
    );
    expect(find.byType(LoadingIndicator), findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });
}
