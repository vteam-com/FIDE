import 'package:fide/models/action_outcome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Runs a panel's actions on the open project: each marks the state busy
/// until it ends, whether it succeeds or fails, and a thrown error becomes
/// a failure to show.
mixin ProjectActions<T> on StateNotifier<T> {
  /// The open project, or null.
  String? get projectPath;

  /// Runs [action] on the open project with the state marked busy by
  /// [busy], turning a thrown error into a failure prefixed by
  /// [failurePrefix]; null when no project is open.
  @protected
  Future<ActionOutcome?> runAction(
    String failurePrefix,
    T Function(T state, bool busy) busy,
    Future<ActionOutcome?> Function(String projectPath) action,
  ) async {
    final path = projectPath;
    if (path == null) return null;
    updateState((state) => busy(state, true));
    try {
      return await action(path);
    } catch (e) {
      return ActionOutcome.failure('$failurePrefix: $e');
    } finally {
      updateState((state) => busy(state, false));
    }
  }

  /// Applies [change] to the state, unless the notifier was disposed while
  /// an action was pending.
  @protected
  void updateState(T Function(T state) change) {
    if (mounted) state = change(state);
  }
}
