part of 'panel_action.dart';

/// A task a live [PanelAction] offers beside its Stop, such as a running
/// app's hot reload: one more task button on the action's row.
class LiveControl {
  /// Creates the control starting its task with [onRun]; its action has
  /// [status] while the task runs.
  const LiveControl({
    required this.icon,
    required this.tooltip,
    required this.status,
    required this.onRun,
  });

  /// Glyph of its button, naming the task.
  final IconData icon;

  /// Starts the task.
  final VoidCallback onRun;

  /// The status of its action while the task runs, which rings its button.
  final ActionStatus status;

  /// Hover text of its button.
  final String tooltip;
}
