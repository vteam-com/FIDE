import 'dart:async';

part 'debouncer.throttle.dart';

/// Runs an action once calls pause for [delay]: each call restarts the
/// wait, so a burst of calls runs only the last one's action, once.
class Debouncer {
  /// Creates a debouncer waiting [delay] after the last call.
  Debouncer(this.delay);

  /// How long calls must pause before the action runs.
  final Duration delay;

  Timer? _timer;

  /// Runs [action] once no other call comes within [delay].
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  /// Drops the pending action, if any.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
