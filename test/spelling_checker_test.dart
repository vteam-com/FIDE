import 'package:fide/services/spelling_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a known word with a regular ending is accepted', () {
    final checker = SpellingChecker({'widget', 'box', 'copy', 'study'});
    final result = checker.check(
      'a.dart',
      'widgets boxes copied studying copies',
    );

    expect(result.findings, isEmpty);
  });

  test('the words named by the user are known without an allowlist', () {
    final checker = SpellingChecker(SpellingChecker.programmingTerms);
    final result = checker.check(
      'a.dart',
      'linux firestore img backend google uint exif rects tooltip tmp',
    );

    expect(result.findings, isEmpty);
  });

  const known = {'adaptive', 'landscape', 'test', 'widget', 'swap', 'sap'};
  final checker = SpellingChecker(known);

  test('splits camelCase and snake_case names into known words', () {
    final result = checker.check(
      'a.dart',
      'adaptiveLandscape adaptive_landscape',
    );

    expect(result.findings, isEmpty);
    expect(result.checked, 4);
  });

  test('flags an unknown word with its line and the nearest known word', () {
    final result = checker.check('a.dart', 'widget\n\n// testx');

    expect(result.findings, hasLength(1));
    final finding = result.findings.single;
    expect(finding.word, 'testx');
    expect(finding.line, 3);
    expect(finding.suggestion, 'test');
  });

  test('a swap of two letters is one edit away', () {
    final result = checker.check('a.dart', 'landsacpe');

    expect(result.findings.single.suggestion, 'landscape');
  });

  test('a word no known word is near has no suggestion', () {
    final result = checker.check('a.dart', 'zzqqxxvv');

    expect(result.findings.single.suggestion, isNull);
  });

  test('short words are not checked', () {
    final result = checker.check('a.dart', 'ab x1');

    expect(result.checked, 0);
    expect(result.findings, isEmpty);
  });

  test('a word matching the known set in any case is known', () {
    final result = checker.check('a.dart', 'WIDGET Widget');

    expect(result.findings, isEmpty);
  });
}
