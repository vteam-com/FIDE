import 'dart:io';

import 'package:fide/providers/code_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// A function long enough for fcheck to compare as duplicate code.
String _sumFunction(String name) =>
    '''
/// Sums [values].
int $name(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 0) {
      total += value;
    } else {
      total -= value;
    }
  }
  final doubled = total * 2;
  final halved = doubled ~/ 2;
  return halved;
}
''';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_review_');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${project.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(_sumFunction('sumA'));
    File('${project.path}/lib/b.dart').writeAsStringSync(_sumFunction('sumB'));
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('quotes both sides of the duplicates fcheck finds', () async {
    const review = CodeReview();
    final metrics = await review.analyze(project.path);
    final findings = await review.duplicates(metrics);

    expect(findings, contains('fcheck found 1 duplicate code pairs.'));
    expect(findings, contains('lib/a.dart:'));
    expect(findings, contains('lib/b.dart:'));
    expect(findings, contains('int sumA(List<int> values) {'));
    expect(findings, contains('int sumB(List<int> values) {'));
  });

  test('lists files and their imports for the design review', () async {
    const review = CodeReview();
    final findings = await review.design(await review.analyze(project.path));

    expect(findings, contains('## Largest classes'));
    expect(findings, contains('## Files importing the most project files'));
    expect(findings, contains('lib/a.dart: 0 imports'));
  });
}
