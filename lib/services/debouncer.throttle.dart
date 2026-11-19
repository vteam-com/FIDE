part of 'debouncer.dart';

/// Runs an action at most once per [interval]: the first call starts the
/// wait, the calls during it join it, and the action of the first runs
/// once it ends, so it should read the latest state when it runs.
class Throttle {
  /// Creates a throttle running at most once per [interval].
  Throttle(this.interval);

  /// Least time between two runs.
  final Duration interval;

  Timer? _timer;

  /// Runs [action] when the current wait ends, starting one when none is.
  void run(void Function() action) {
    _timer ??= Timer(interval, () {
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
