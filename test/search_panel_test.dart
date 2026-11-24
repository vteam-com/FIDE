import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/panels/left/search_panel.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/project_search_service.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The project searched.
const String _project = '/project';

/// The file every match is in, right under lib/.
final String _file = p.join(_project, 'lib', 'many.dart');

/// [count] matches of `foo`, one per line of [_file].
List<SearchResult> _matches(int count) => [
  for (var line = 1; line <= count; line++)
    SearchResult(
      filePath: _file,
      lineNumber: line,
      lineContent: 'foo $line',
      matchStart: 0,
      matchEnd: 'foo'.length,
    ),
];

/// A search answering each query from [answers], when its completer
/// completes.
class _FakeSearch extends ProjectSearchService {
  _FakeSearch(this.answers);

  /// The pending answer of each query.
  final Map<String, Completer<ProjectSearchHits>> answers;

  @override
  Future<ProjectSearchHits> search(
    String directoryPath,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
    int limit = AppMetric.projectSearchMaxResults,
  }) => answers[query]!.future;

  @override
  Future<ProjectSearchHits> searchFolders(
    List<String> directories,
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
    int limit = AppMetric.projectSearchMaxResults,
  }) => answers[query]!.future;
}

/// Shows the Search tab answered by [search].
Future<void> _pumpPanel(WidgetTester tester, _FakeSearch search) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [projectSearchServiceProvider.overrideWithValue(search)],
      child: const MaterialApp(
        home: Scaffold(body: SearchPanel(projectPath: _project)),
      ),
    ),
  );
}

/// Types [query] in the search field and submits it.
Future<void> _searchFor(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('thousands of matches build only the rows on screen', (
    tester,
  ) async {
    const listed = AppMetric.projectSearchMaxResults;
    const unlisted = 3000;
    final answer = Completer<ProjectSearchHits>()
      ..complete((
        results: _matches(listed),
        files: [_file],
        total: listed + unlisted,
      ));
    await _pumpPanel(tester, _FakeSearch({'foo': answer}));

    await _searchFor(tester, 'foo');
    await tester.pump();

    final built = find.byType(LocationRow).evaluate().length;
    expect(built, greaterThan(0));
    // A screenful, not the listed matches
    expect(built, lessThan(listed ~/ 10));

    // The last row tells how many more there are
    await tester.dragUntilVisible(
      find.textContaining('3,000 more not listed'),
      find.byType(ListView),
      const Offset(0, -10000),
    );
    expect(find.textContaining('3,000 more not listed'), findsOneWidget);
  });

  testWidgets('a slow older search does not replace a newer one', (
    tester,
  ) async {
    final slow = Completer<ProjectSearchHits>();
    final fast = Completer<ProjectSearchHits>();
    await _pumpPanel(tester, _FakeSearch({'old': slow, 'new': fast}));

    await _searchFor(tester, 'old');
    await _searchFor(tester, 'new');
    fast.complete((results: _matches(1), files: [_file], total: 1));
    await tester.pump();
    slow.complete((results: _matches(2), files: [_file], total: 2));
    await tester.pump();

    expect(find.byType(LocationRow), findsOneWidget);
  });
}
