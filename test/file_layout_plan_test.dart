import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/import_graph.dart';
import 'package:flutter_test/flutter_test.dart';

/// The move of the model at [path] to `lib/models`.
FileMove _toModels(String path) => FileMove(
  category: CodeCategory.models,
  path: path,
  target: 'lib/models/${path.split('/').last}',
  name: path,
  line: 1,
);

/// `lib/p/a.dart` uses `lib/r/c.dart`, which `lib/r/f.dart` uses too;
/// `lib/r/e.dart` uses `lib/r/d.dart`. Moving a or d to `lib/models` is
/// fine alone, but both would make `lib/models` and `lib/r` depend on
/// each other, and no file can move along to prevent it.
final FileMove _a = _toModels('lib/p/a.dart');
final FileMove _d = _toModels('lib/r/d.dart');
final FileLayoutReview _review = FileLayoutReview(
  moves: [_a, _d],
  fileCount: 5,
  graph: const ImportGraph({
    'lib/p/a.dart': {'lib/r/c.dart'},
    'lib/r/c.dart': {},
    'lib/r/d.dart': {},
    'lib/r/e.dart': {'lib/r/d.dart'},
    'lib/r/f.dart': {'lib/r/c.dart'},
  }),
);

void main() {
  test('each move alone adds no Layers issue', () {
    for (final plan in _review.planEach([_a, _d])) {
      expect(plan.addedIssue, isNull);
    }
  });

  test('the moves together would add one', () {
    expect(_review.plan([_a, _d]).addedIssue, isNotNull);
  });

  test('Move All moves as many as go together, leaving the others', () {
    final plan = _review.planAll([_a, _d]);

    expect(plan.addedIssue, isNull);
    expect(plan.moves, [_a]);
  });
}
