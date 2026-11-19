import 'package:fide/services/debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long the debouncer and throttle under test wait.
const Duration _wait = Duration(milliseconds: 10);

/// Calls made in a burst.
const int _burst = 3;

void main() {
  test('Debouncer runs only the last action, once calls pause', () async {
    final debouncer = Debouncer(_wait);
    final runs = <int>[];
    for (var call = 0; call < _burst; call++) {
      debouncer.run(() => runs.add(call));
    }

    await Future<void>.delayed(_wait * _burst);

    expect(runs, [_burst - 1]);
  });

  test('Throttle runs the first action once per interval', () async {
    final throttle = Throttle(_wait);
    final runs = <int>[];
    for (var call = 0; call < _burst; call++) {
      throttle.run(() => runs.add(call));
    }

    await Future<void>.delayed(_wait * _burst);

    expect(runs, [0]);
  });

  test('cancel drops the pending action', () async {
    final debouncer = Debouncer(_wait);
    var ran = false;
    debouncer
      ..run(() => ran = true)
      ..cancel();

    await Future<void>.delayed(_wait * _burst);

    expect(ran, isFalse);
  });
}
