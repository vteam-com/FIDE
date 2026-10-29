import 'dart:io';

import 'package:fide/providers/project_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory lib;

  setUp(() {
    lib = Directory.systemTemp.createTempSync('fide_search_');
    File(p.join(lib.path, 'a.dart')).writeAsStringSync('foo\nfood Foo\n');
    File(p.join(lib.path, 'src', 'b.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('no match\nfoo\n');
  });

  tearDown(() => lib.deleteSync(recursive: true));

  const service = ProjectSearchService();

  test('finds matches with line numbers and offsets', () async {
    final results = await service.search(lib.path, 'foo', caseSensitive: true);

    final inA = results.where((r) => r.filePath.endsWith('a.dart')).toList();
    expect(
      [for (final r in inA) (r.lineNumber, r.matchStart)],
      [(1, 0), (2, 0)],
    );
    expect(results, hasLength(3));
  });

  test('whole word skips longer words', () async {
    final results = await service.search(lib.path, 'foo', wholeWord: true);

    expect(results.map((r) => r.lineContent), isNot(contains('food')));
    expect(results, hasLength(3));
  });

  test('groups results into a sorted folder tree', () async {
    final results = await service.search(lib.path, 'foo');

    final tree = service.toTree(results, lib.path)!;

    expect([for (final child in tree.children) child.name], ['src', 'a.dart']);
    expect(tree.children.first.children.single.name, 'b.dart');
  });

  test('no results give no tree', () {
    expect(service.toTree(const [], lib.path), isNull);
  });
}
