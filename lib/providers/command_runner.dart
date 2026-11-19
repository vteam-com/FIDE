import 'dart:async';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/command_runs.dart';
import 'package:fide/models/hot_reload.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/services/debouncer.dart';
import 'package:fide/services/flutter_app_session.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:flutter_riverpod/legacy.dart';

part 'command_runner.build_narration.dart';

/// Error output of the last failed Execute panel action; empty once an
/// action succeeds. The AI panel's Fix Build sends it to the model.
final lastBuildErrorsProvider = StateProvider<String>((_) => '');

/// The panel actions' runs, which outlive the panels: switching tabs keeps
/// `flutter run` going and its log visible. Every run stops when the
/// project changes or closes, and each save hot reloads the apps running.
final commandRunnerProvider = StateNotifierProvider<CommandRunner, CommandRuns>(
  (ref) {
    final runner = CommandRunner(
      onBuildErrors: (errors) =>
          ref.read(lastBuildErrorsProvider.notifier).state = errors,
    );
    ref.listen(currentProjectPathProvider, (_, _) => runner.reset());
    ref.listen(savedFilesRevisionProvider, (_, _) => runner.reloadApps());
    return runner;
  },
);

/// Runs command-backed panel actions (build, run, test...), keeping one
/// status and one live process per action id, so actions run side by side
/// and each can be stopped, and their output in logs keyed by the caller.
///
/// An app run ([BuildOutput.onAppStarted]) turns [ActionStatus.live] once
/// launched, then [reloadApp] hot reloads it, and stopping it asks the
/// Flutter tool to stop the app before killing the tool.
///
/// Processes are killed only by [stop], [reset] or [dispose]. Log lines
/// are shown at most every [AppDuration.outputLogPublish], so a burst of
/// output doesn't rebuild its views once per line; status changes, and
/// the lines written before them, are shown at once.
class CommandRunner extends StateNotifier<CommandRuns> {
  /// Creates a runner with no runs, reporting the errors of each run with
  /// `reportsBuildErrors` (none after a success) to [onBuildErrors].
  CommandRunner({required this._onBuildErrors}) : super(const CommandRuns());

  /// Mark before the line closing a run that succeeded.
  static const String successMark = '✓ ';

  /// Mark before the line closing a run that failed or threw.
  static const String failureMark = '✗ ';

  /// Line closing a run [stop] ended.
  static const String stoppedLine = '⏹ Stopped';

  /// Bumped by [reset], so runs it ended stop reporting.
  int _generation = 0;

  final void Function(String errors) _onBuildErrors;

  final Map<String, Process> _processes = {};

  final Set<String> _stopping = {};

  /// The sessions of the apps launched, by action id.
  final Map<String, FlutterAppSession> _apps = {};

  /// Reloads asked while the app was reloading, by action id: a hot
  /// restart when any asked for one.
  final Map<String, HotReload> _pendingReloads = {};

  /// Pending publication of log lines written since the last one.
  final Throttle _logPublish = Throttle(AppDuration.outputLogPublish);

  /// Discards the text of log [logKey].
  void clearLog(String logKey) {
    _write(logKey, (log) => log.clear());
    _publish(state.statuses);
  }

  @override
  void dispose() {
    _logPublish.cancel();
    _killAll();
    super.dispose();
  }

  /// Stops every run and forgets every status and log, e.g. when the
  /// project closes.
  void reset() {
    _generation++;
    _killAll();
    _logPublish.cancel();
    state = const CommandRuns();
  }

  /// Runs action [id]: clears log [logKey], marks the action running with
  /// [startMessages], then records success or failure from the exit code
  /// [command] returns or the error it throws. [command] reports through
  /// the [BuildOutput] it is given, which writes to the log and tracks the
  /// processes it starts. Returns whether it succeeded.
  ///
  /// The run ends with [successMessage], [failureMessage] or [errorPrefix]
  /// then the error, each after its [successMark] or [failureMark]: every
  /// panel's runs close alike.
  ///
  /// The status returns to idle after a pause, except when [resetWhenDone]
  /// is false (app runs), whose final state stays visible. The action
  /// turns [ActionStatus.live] once the app it runs has launched. With
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
          // Later steps of a stopped or ended run don't get to run
          onProcessStarted: (process) {
            if (isCurrent() && !_stopping.contains(id)) {
              _processes[id] = process;
            } else {
              process.kill();
            }
          },
          onAppStarted: (session) {
            if (isCurrent() && !_stopping.contains(id)) {
              _addApp(id, session);
            } else {
              unawaited(session.stop());
            }
          },
        ),
      );
      final stopped = _stopping.contains(id);
      succeeded = !stopped && exitCode == 0;
      if (stopped) {
        write((log) => log.addOutput(stoppedLine));
        setStatus(ActionStatus.idle);
      } else if (succeeded) {
        write((log) => log.addOutput('$successMark$successMessage'));
        setStatus(ActionStatus.success);
      } else {
        write((log) => log.addError('$failureMark${failureMessage(exitCode)}'));
        setStatus(ActionStatus.error);
      }
    } on BuildException catch (e) {
      write(
        (log) =>
            log.addError('$failureMark$errorPrefix${BuildNarration.failed(e)}'),
      );
      setStatus(ActionStatus.error);
    } catch (e) {
      write((log) => log.addError('$failureMark$errorPrefix$e'));
      setStatus(ActionStatus.error);
    } finally {
      if (isCurrent()) {
        _processes.remove(id);
        _stopping.remove(id);
        _removeApp(id);
      }
    }
    if (reportsBuildErrors && isCurrent()) {
      _onBuildErrors(succeeded ? '' : state.logOf(logKey).errors);
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

  /// Applies the saved code to the app action [id] runs with [kind]; a
  /// hot reload that can't apply a change restarts it
  /// ([FlutterAppSession.reloadOrRestart]). The action has the status of
  /// the kind applying meanwhile, and a reload asked then follows it, once.
  /// Its errors, or none after a success, become [lastBuildErrorsProvider]
  /// for the AI's Fix Build. Does nothing unless the app is live and hot
  /// reloads.
  Future<void> reloadApp(String id, [HotReload kind = HotReload.reload]) async {
    final app = _apps[id];
    if (app == null || !state.reloadable.contains(id)) return;
    final status = state.statusOf(id);
    if (status.isReloading) {
      if (_pendingReloads[id] != HotReload.restart) _pendingReloads[id] = kind;
      return;
    }
    if (status != ActionStatus.live) return;
    _setStatus(id, kind.status);
    final error = switch (kind) {
      HotReload.reload => await app.reloadOrRestart(
        onRestart: () {
          if (_apps[id] == app) _setStatus(id, HotReload.restart.status);
        },
      ),
      HotReload.restart => await app.reload(full: true),
    };
    // Stopped, ended or reset meanwhile
    if (_apps[id] != app) return;
    _setStatus(id, ActionStatus.live);
    _onBuildErrors(error ?? '');
    final pending = _pendingReloads.remove(id);
    if (pending != null) await reloadApp(id, pending);
  }

  /// Applies the saved code with [kind] to every app running that hot
  /// reloads ([reloadApp]).
  Future<void> reloadApps([HotReload kind = HotReload.reload]) =>
      Future.wait([for (final id in state.reloadable) reloadApp(id, kind)]);

  /// Stops action [id], if it has a process running: asks the Flutter tool
  /// to stop the app it launched, else kills the process.
  void stop(String id) {
    final app = _apps[id];
    final process = _processes[id];
    if (app == null && process == null) return;
    _stopping.add(id);
    if (app != null) {
      unawaited(app.stop());
    } else {
      process?.kill();
    }
  }

  /// Keeps the [session] of the app action [id] launched, which turns it
  /// live.
  void _addApp(String id, FlutterAppSession session) {
    _apps[id] = session;
    _publish(
      {...state.statuses, id: ActionStatus.live},
      reloadable: session.supportsRestart
          ? {...state.reloadable, id}
          : state.reloadable,
    );
  }

  /// Forgets the app of action [id], once its run ends.
  void _removeApp(String id) {
    _apps.remove(id);
    _pendingReloads.remove(id);
    if (!state.reloadable.contains(id)) return;
    _publish(state.statuses, reloadable: {...state.reloadable}..remove(id));
  }

  /// Stops every app and kills every other live process.
  void _killAll() {
    for (final app in _apps.values) {
      unawaited(app.stop());
    }
    for (final MapEntry(:key, value: process) in _processes.entries) {
      if (!_apps.containsKey(key)) process.kill();
    }
    _apps.clear();
    _pendingReloads.clear();
    _processes.clear();
    _stopping.clear();
  }

  /// Publishes [statuses] with the logs as they are now, including lines
  /// still waiting for [_logPublish], and the [reloadable] apps.
  void _publish(
    Map<String, ActionStatus> statuses, {
    Map<String, OutputLog>? logs,
    Set<String>? reloadable,
  }) {
    _logPublish.cancel();
    state = CommandRuns(
      statuses: statuses,
      logs: logs ?? state.logs,
      reloadable: reloadable ?? state.reloadable,
    );
  }

  /// Sets the status of action [id].
  void _setStatus(String id, ActionStatus status) =>
      _publish({...state.statuses, id: status});

  /// Applies [change] to log [logKey], kept in place, so the current state
  /// holds it at once; a new log is published at once, more lines within
  /// [AppDuration.outputLogPublish].
  void _write(String logKey, void Function(OutputLog log) change) {
    final log = state.logs[logKey];
    if (log == null) {
      final created = OutputLog();
      change(created);
      _publish(state.statuses, logs: {...state.logs, logKey: created});
      return;
    }
    change(log);
    _logPublish.run(() => _publish(state.statuses));
  }
}
