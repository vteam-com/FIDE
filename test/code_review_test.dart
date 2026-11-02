import 'dart:io';

import 'package:fide/services/ai_assistant.dart';
import 'package:fide/services/code_review.dart';
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
    final findings = await const ReviewFindings().duplicates(metrics);

    expect(findings, contains('fcheck found 1 duplicate code pairs.'));
    expect(findings, contains('lib/a.dart:'));
    expect(findings, contains('lib/b.dart:'));
    expect(findings, contains('int sumA(List<int> values) {'));
    expect(findings, contains('int sumB(List<int> values) {'));
  });

  test('lists files and their imports for the design review', () async {
    const review = CodeReview();
    final findings = await const ReviewFindings().design(
      await review.analyze(project.path),
    );

    expect(findings, contains('## Largest classes'));
    expect(findings, contains('## Files importing the most project files'));
    expect(findings, contains('lib/a.dart: 0 imports'));
  });

  test('sorts members with fcheck and lists the files it rewrote', () async {
    final unsorted = File('${project.path}/lib/c.dart')
      ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

/// A sample.
class Sample extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox();

  /// Creates a sample.
  const Sample({super.key});
}
''');

    final changed = await const CodeReview().sortMembers(project.path);

    expect(changed, [unsorted.path]);
    final sorted = unsorted.readAsStringSync();
    expect(
      sorted.indexOf('const Sample('),
      lessThan(sorted.indexOf('Widget build')),
    );
  });
}
