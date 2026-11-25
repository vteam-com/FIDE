import 'package:fide/services/blocking_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ticks off the files it is done with, the one at work in between', () {
    final task = BlockingTask('Analyzing')..startFile('/p/a.dart');
    expect(task.working.value, '/p/a.dart');

    task.finishFiles(['/p/a.dart', '/p/a.part.dart'], succeeded: true);
    task.startFile('/p/b.dart');
    task.finishFiles(['/p/b.dart'], succeeded: false);

    expect(task.working.value, isNull);
    expect(task.finished.value, {
      '/p/a.dart': true,
      '/p/a.part.dart': true,
      '/p/b.dart': false,
    });
    task.dispose();
  });

  test('a task confirmed before it started asks nothing', () async {
    final task = BlockingTask('Analyzing', confirmed: true);

    expect(await task.confirm('Fix?', confirmLabel: 'Fix'), isTrue);
    expect(task.question.value, isNull);
    task.dispose();
  });
}
