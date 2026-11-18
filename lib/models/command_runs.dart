import 'package:fide/models/action_status.dart';
import 'package:fide/models/output_log.dart';

/// What the command-backed panel actions are doing: one status per action
/// id and one output log per log key (a panel, or one of its targets).
class CommandRuns {
  /// Status of each action that has run, by action id.
  final Map<String, ActionStatus> statuses;

  /// Output of each log, by log key.
  final Map<String, OutputLog> logs;

  /// The actions whose app has launched and hot reloads.
  final Set<String> reloadable;

  /// Creates a snapshot of [statuses], [logs] and the [reloadable] apps.
  const CommandRuns({
    this.statuses = const {},
    this.logs = const {},
    this.reloadable = const {},
  });

  /// Whether any app runs that a hot reload or restart applies to.
  bool get canReload => reloadable.isNotEmpty;

  /// Whether any of the actions [ids] is working toward a result, as a
  /// progress ring shows ([ActionStatusResult.isBusy]).
  bool isAnyBusy(Iterable<String> ids) => ids.any((id) => statusOf(id).isBusy);

  /// Whether any of the actions [ids] is in progress.
  bool isAnyRunning(Iterable<String> ids) => ids.any(isRunning);

  /// Whether action [id] is in progress.
  bool isRunning(String id) => statusOf(id).isInProgress;

  /// The log kept under [key]; an empty one when nothing wrote to it yet.
  OutputLog logOf(String key) => logs[key] ?? OutputLog();

  /// Current status of action [id].
  ActionStatus statusOf(String id) => statuses[id] ?? ActionStatus.idle;
}
