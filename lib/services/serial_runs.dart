import 'dart:async';

/// Runs a costly analysis one run at a time: a run asked for while another
/// is going waits for it to end, and is skipped when a newer one
/// superseded it meanwhile, so only the latest of those queued starts.
class SerialRuns {
  /// Ends when the last run queued has ended, or was skipped.
  Future<void> _last = Future<void>.value();

  /// Runs [task] once the runs queued before it have ended, unless
  /// [isCurrent] is false by then; null when skipped, and when [isCurrent]
  /// turned false while [task] ran, so a stale result never lands.
  Future<T?> run<T>(
    Future<T> Function() task, {
    required bool Function() isCurrent,
  }) async {
    final previous = _last;
    final done = Completer<void>();
    _last = done.future;
    try {
      await previous;
      if (!isCurrent()) return null;
      final result = await task();
      return isCurrent() ? result : null;
    } finally {
      done.complete();
    }
  }
}
