import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';

/// Reports a multi-step job, such as loading a project, as a numbered log
/// of [LoadingAction]s, pausing after each finished step so the loading
/// screen shows it before the next replaces the focus.
class LoadingProgress {
  /// Creates a reporter publishing each new log to [_publish], pausing
  /// [pace] after each finished step.
  LoadingProgress(this._publish, {this.pace = AppDuration.projectLoadDelay});

  final void Function(List<LoadingAction> actions) _publish;

  /// How long each finished step stays in focus.
  final Duration pace;

  List<LoadingAction> _actions = const [];

  /// Starts a new, empty log.
  void start() => _set(const []);

  /// Logs [text] as the next step and runs [action], marking the step
  /// succeeded or failed by its result; an exception also fails it, then
  /// propagates. Returns the result.
  Future<bool> step(String text, FutureOr<bool> Function() action) async {
    final number = _actions.length + 1;
    _set([..._actions, LoadingAction(number, text, LoadingStatus.pending)]);
    final bool succeeded;
    try {
      succeeded = await action();
    } catch (_) {
      _mark(number, LoadingStatus.failed);
      await Future<void>.delayed(pace);
      rethrow;
    }
    _mark(number, succeeded ? LoadingStatus.success : LoadingStatus.failed);
    if (succeeded) await Future<void>.delayed(pace);
    return succeeded;
  }

  /// Gives step [number] [status].
  void _mark(int number, LoadingStatus status) => _set([
    for (final action in _actions)
      action.step == number
          ? LoadingAction(action.step, action.text, status)
          : action,
  ]);

  void _set(List<LoadingAction> actions) {
    _actions = actions;
    _publish(actions);
  }
}
