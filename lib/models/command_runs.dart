import 'package:fide/models/action_status.dart';
import 'package:fide/models/output_log.dart';

/// What the command-backed panel actions are doing: one status per action
/// id and one output log per log key (a panel, or one of its targets).
class CommandRuns {
  /// Status of each action that has run, by action id.
  final Map<String, ActionStatus> statuses;

  /// Output of each log, by log key.
  final Map<String, OutputLog> logs;

  /// Creates a snapshot of [statuses] and [logs].
  const CommandRuns({this.statuses = const {}, this.logs = const {}});

  /// Whether any of the actions [ids] is in progress.
  bool isAnyRunning(Iterable<String> ids) => ids.any(isRunning);

  /// Whether action [id] is in progress.
  bool isRunning(String id) => statusOf(id) == ActionStatus.running;

  /// The log kept under [key]; an empty one when nothing wrote to it yet.
  OutputLog logOf(String key) => logs[key] ?? OutputLog();

  /// Current status of action [id].
  ActionStatus statusOf(String id) => statuses[id] ?? ActionStatus.idle;
}
