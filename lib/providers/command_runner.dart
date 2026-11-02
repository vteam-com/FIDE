import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/command_runs.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The panel actions' runs, which outlive the panels: switching tabs keeps
/// `flutter run` going and its log visible. Every run stops when the
/// project changes or closes.
final commandRunnerProvider = StateNotifierProvider<CommandRunner, CommandRuns>(
  (ref) {
    final runner = CommandRunner(ref);
    ref.listen(currentProjectPathProvider, (_, _) => runner.reset());
    return runner;
  },
);

/// Runs command-backed panel actions (build, run, test...), keeping one
/// status and one live process per action id, so actions run side by side
/// and each can be stopped, and their output in logs keyed by the caller.
///
/// Processes are killed only by [stop], [reset] or [dispose].
class CommandRunner extends StateNotifier<CommandRuns> {
  /// Creates a runner with no runs, reading providers through [_ref].
  CommandRunner(this._ref) : super(const CommandRuns());

  /// Bumped by [reset], so runs it ended stop reporting.
  int _generation = 0;

  final Map<String, Process> _processes = {};

  final Ref _ref;

  final Set<String> _stopping = {};

  /// Discards the text of log [logKey].
  void clearLog(String logKey) => _write(logKey, (log) => log.clear());

  @override
  void dispose() {
    _killAll();
    super.dispose();
  }

  /// Stops every run and forgets every status and log, e.g. when the
  /// project closes.
  void reset() {
    _generation++;
    _killAll();
    state = const CommandRuns();
  }

  /// Runs action [id]: clears log [logKey], marks the action running with
  /// [startMessages], then records success or failure from the exit code
  /// [command] returns or the error it throws. [command] reports through
  /// the [BuildOutput] it is given, which writes to the log and tracks the
  /// processes it starts. Returns whether it succeeded.
  ///
  /// The status returns to idle after a pause, except when [resetWhenDone]
  /// is false (app runs), whose final state stays visible. With
  /// [reportsBuildErrors], the errors of a failure, or none after a
  /// success, become [lastBuildErrorsProvider] for the AI's Fix Build.
  Future<bool> run(
    String id, {
    required String logKey,
    required List<String> startMessages,
    required Future<int> Function(BuildOutput output) command,
    required String successMessage,
    required String Function(int) failureMessage,
    required String errorPrefix,
    bool resetWhenDone = true,
    bool reportsBuildErrors = false,
  }) async {
    // A reset ends this run: whatever it still reports is dropped
    final generation = _generation;
    bool isCurrent() => mounted && generation == _generation;
    void write(void Function(OutputLog log) change) {
      if (isCurrent()) _write(logKey, change);
    }

    void setStatus(ActionStatus status) {
      if (isCurrent()) _setStatus(id, status);
    }

    write((log) {
      log.clear();
      startMessages.forEach(log.addOutput);
    });
    setStatus(ActionStatus.running);

    var succeeded = false;
    try {
      final exitCode = await command(
        BuildOutput(
          onOutput: (text) => write((log) => log.addOutput(text)),
          onError: (text) => write((log) => log.addError(text)),
          onResetErrors: () => write((log) => log.clearErrors()),
          // Later steps of a stopped or ended run don't get to run
          onProcessStarted: (process) {
            if (isCurrent() && !_stopping.contains(id)) {
              _processes[id] = process;
            } else {
              process.kill();
            }
          },
        ),
      );
      final stopped = _stopping.contains(id);
      succeeded = !stopped && exitCode == 0;
      if (stopped) {
        write((log) => log.addOutput('⏹ Stopped'));
        setStatus(ActionStatus.idle);
      } else if (succeeded) {
        write((log) => log.addOutput(successMessage));
        setStatus(ActionStatus.success);
      } else {
        write((log) => log.addError(failureMessage(exitCode)));
        setStatus(ActionStatus.error);
      }
    } catch (e) {
      write((log) => log.addError('$errorPrefix$e'));
      setStatus(ActionStatus.error);
    } finally {
      if (isCurrent()) {
        _processes.remove(id);
        _stopping.remove(id);
      }
    }
    if (reportsBuildErrors && isCurrent()) {
      _ref.read(lastBuildErrorsProvider.notifier).state = succeeded
          ? ''
          : state.logOf(logKey).errors;
    }
    if (resetWhenDone) {
      Future.delayed(AppDuration.buildStatusResetDelay, () {
        if (isCurrent() && !state.isRunning(id)) {
          _setStatus(id, ActionStatus.idle);
        }
      });
    }
    return succeeded;
  }

  /// Kills the process of action [id], if it has one running.
  void stop(String id) {
    final process = _processes[id];
    if (process == null) return;
    _stopping.add(id);
    process.kill();
  }

  /// Kills every live process.
  void _killAll() {
    for (final process in _processes.values) {
      process.kill();
    }
    _processes.clear();
    _stopping.clear();
  }

  /// Sets the status of action [id].
  void _setStatus(String id, ActionStatus status) => state = CommandRuns(
    statuses: {...state.statuses, id: status},
    logs: state.logs,
  );

  /// Applies [change] to log [logKey] and publishes it.
  void _write(String logKey, void Function(OutputLog log) change) {
    final log = state.logs[logKey] ?? OutputLog();
    change(log);
    state = CommandRuns(
      statuses: state.statuses,
      logs: {...state.logs, logKey: log},
    );
  }
}
