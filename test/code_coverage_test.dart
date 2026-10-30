import 'package:fide/models/code_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sums line coverage across every lcov record', () {
    final coverage = CodeCoverage.fromLcov('''
SF:lib/a.dart
DA:1,1
LF:10
LH:7
end_of_record
SF:lib/b.dart
LF:30
LH:13
end_of_record
''');

    expect(coverage.linesFound, 40);
    expect(coverage.linesHit, 20);
    expect(coverage.percent, 50);
  });

  test('reports zero for an empty report', () {
    expect(CodeCoverage.fromLcov('').percent, 0);
  });
}
