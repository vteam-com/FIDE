import 'dart:isolate';

import 'package:fide/models/search_result.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests cross to the worker isolate with their fields', () async {
    final rename = await Isolate.run(
      () => const RenameRequest('/p/a.dart', 2, 3, 'B'),
    );
    expect(
      (rename.filePath, rename.line, rename.column, rename.newName),
      ('/p/a.dart', 2, 3, 'B'),
    );

    final check = await Isolate.run(
      () => const CheckCompilesRequest({'/p/a.dart': 'class B {}'}, 'Renaming'),
    );
    expect(check.contents, {'/p/a.dart': 'class B {}'});
    expect(check.action, 'Renaming');
  });

  test('each request reads its answer as its own type', () {
    const find = FindReferencesRequest('/p/a.dart', 1, 1);
    expect(find.answerFrom(<SearchResult>[]), isA<List<SearchResult>>());
    expect(
      () => find.answerFrom(<String, String>{}),
      throwsA(isA<TypeError>()),
    );

    const rename = RenameRequest('/p/a.dart', 1, 1, 'B');
    expect(rename.answerFrom({'/p/a.dart': ''}), {'/p/a.dart': ''});
    expect(() => rename.answerFrom(null), throwsA(isA<TypeError>()));

    const lookup = LookupFieldRequest('/p/a.dart', 0);
    expect(() => lookup.answerFrom('field'), throwsA(isA<TypeError>()));
  });

  test('a compile check answers nothing', () {
    const check = CheckCompilesRequest({}, 'Renaming');
    expect(() => check.answerFrom(null), returnsNormally);
  });
}
