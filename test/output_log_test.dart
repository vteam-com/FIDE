import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/output_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps each line followed by a newline', () {
    final log = OutputLog()
      ..addOutput('one')
      ..addOutput('two\nthree')
      ..addError('');

    expect(log.output, 'one\ntwo\nthree\n');
    expect(log.errors, '\n');
    expect(log.hasErrors, isTrue);
  });

  test('keeps only the newest lines and says how many were dropped', () {
    const extra = 3;
    final log = OutputLog();
    for (var i = 0; i < AppMetric.outputLogMaxLines + extra; i++) {
      log.addOutput('line $i');
    }

    final lines = log.output.split('\n');
    expect(lines.first, '… $extra earlier lines dropped');
    expect(lines[1], 'line $extra');
    // The marker, the kept lines and the empty text after the last newline
    expect(lines, hasLength(AppMetric.outputLogMaxLines + 2));
  });

  test('builds its text once per change, not on every read', () {
    final log = OutputLog()..addOutput('one');
    final first = log.output;

    expect(identical(log.output, first), isTrue);
    log.addOutput('two');
    expect(identical(log.output, first), isFalse);
  });

  test('clear forgets the lines and the dropped count', () {
    final log = OutputLog();
    for (var i = 0; i <= AppMetric.outputLogMaxLines; i++) {
      log.addOutput('line $i');
    }

    log.clear();
    log.addOutput('fresh');

    expect(log.output, 'fresh\n');
    expect(log.hasErrors, isFalse);
  });
}
