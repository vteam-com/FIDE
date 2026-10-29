import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/output_log.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs command-backed panel actions into [actionLog], keeping one status
/// and one live process per action id so actions can run side by side and
/// each can be stopped. Every process still running is killed on dispose.
mixin CommandActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Map<String, ActionStatus> _statuses = {};
  final Map<String, Process> _processes = {};
  final Set<String> _stopping = {};

  /// The log actions write their output to.
  OutputLog get actionLog;

  /// Whether any action is in progress.
  bool get isAnyActionRunning =>
      _statuses.values.contains(ActionStatus.running);

  @override
  void dispose() {
    for (final process in _processes.values) {
      process.kill();
    }
    _processes.clear();
    super.dispose();
  }

  /// Runs action [id]: clears the log, marks it running with
  /// [startMessages], then records success or failure from the exit code
  /// [command] returns or the error it throws. Returns whether it
  /// succeeded.
  ///
  /// The status returns to idle after a pause, except when [resetWhenDone]
  /// is false (app runs), whose final state stays visible.
  Future<bool> runCommandAction(
    String id, {
    required List<String> startMessages,
    required Future<int> Function() command,
    required String successMessage,
    required String Function(int) failureMessage,
    required String errorPrefix,
    bool resetWhenDone = true,
  }) async {
    _update(() {
      actionLog.clear();
      _statuses[id] = ActionStatus.running;
      startMessages.forEach(actionLog.addOutput);
    });

    var succeeded = false;
    try {
      final exitCode = await command();
      final stopped = _stopping.contains(id);
      succeeded = !stopped && exitCode == 0;
      _update(() {
        if (stopped) {
          _statuses[id] = ActionStatus.idle;
          actionLog.addOutput('⏹ Stopped');
        } else if (succeeded) {
          _statuses[id] = ActionStatus.success;
          actionLog.addOutput(successMessage);
        } else {
          _statuses[id] = ActionStatus.error;
          actionLog.addError(failureMessage(exitCode));
        }
      });
    } catch (e) {
      _update(() {
        _statuses[id] = ActionStatus.error;
        actionLog.addError('$errorPrefix$e');
      });
    } finally {
      _processes.remove(id);
      _stopping.remove(id);
      if (resetWhenDone) {
        Future.delayed(AppDuration.buildStatusResetDelay, () {
          if (statusOf(id) != ActionStatus.running) {
            _update(() => _statuses[id] = ActionStatus.idle);
          }
        });
      }
    }
    return succeeded;
  }

  /// Current status of action [id].
  ActionStatus statusOf(String id) => _statuses[id] ?? ActionStatus.idle;

  /// Kills the process of action [id], if it has one running.
  void stopAction(String id) {
    final process = _processes[id];
    if (process == null) return;
    _stopping.add(id);
    process.kill();
  }

  /// Records [process] as the live process of action [id], so it can be
  /// stopped and is killed on dispose.
  void trackProcess(String id, Process process) => _processes[id] = process;

  /// Applies [fn] with `setState` while the panel is still mounted.
  void _update(VoidCallback fn) {
    if (mounted) setState(fn);
  }
}
