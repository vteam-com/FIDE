import 'dart:async';

import 'package:fide/services/serial_runs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs one at a time, starting only the latest run queued', () async {
    final runs = SerialRuns();
    final first = Completer<String>();
    final started = <String>[];
    var running = 0;
    var mostRunning = 0;
    Future<String> task(String name, [Future<String>? until]) async {
      started.add(name);
      mostRunning = ++running > mostRunning ? running : mostRunning;
      final result = await (until ?? Future.value(name));
      running--;
      return result;
    }

    final a = runs.run(() => task('a', first.future), isCurrent: () => true);
    // Superseded by c before a ends
    var bCurrent = true;
    final b = runs.run(() => task('b'), isCurrent: () => bCurrent);
    final c = runs.run(() => task('c'), isCurrent: () => true);
    bCurrent = false;
    first.complete('a');

    expect(await a, 'a');
    expect(await b, isNull);
    expect(await c, 'c');
    expect(started, ['a', 'c']);
    expect(mostRunning, 1);
  });

  test('drops the result of a run superseded while it ran', () async {
    final runs = SerialRuns();
    var current = true;

    final result = runs.run(() async {
      current = false;
      return 'stale';
    }, isCurrent: () => current);

    expect(await result, isNull);
  });

  test('a failed run lets the next one start', () async {
    final runs = SerialRuns();

    final failed = runs.run<String>(
      () async => throw StateError('broken'),
      isCurrent: () => true,
    );
    final next = runs.run(() async => 'next', isCurrent: () => true);

    await expectLater(failed, throwsStateError);
    expect(await next, 'next');
  });
}
