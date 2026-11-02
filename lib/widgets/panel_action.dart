import 'package:fide/models/action_status.dart';
import 'package:flutter/widgets.dart';

/// One action a panel offers (build, run, run tests...), with what the UI
/// needs to present, start and stop it.
class PanelAction {
  /// Stable id, also used to track the action's status and process.
  final String id;

  /// Short name.
  final String title;

  /// One-line summary.
  final String description;

  /// Longer explanation shown in the details view.
  final String details;

  /// Icon shown on the action's tab or tile.
  final IconData icon;

  /// Starts the action.
  final VoidCallback onRun;

  /// Stops the running action; null when it can't be stopped.
  final VoidCallback? onStop;

  /// Current progress.
  final ActionStatus status;

  /// Creates an action description.
  const PanelAction({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
    required this.icon,
    required this.onRun,
    this.onStop,
    this.status = ActionStatus.idle,
  });

  /// Whether the action is in progress.
  bool get isRunning => status == ActionStatus.running;

  /// This action at [status], stopped by [onStop].
  PanelAction withProgress(ActionStatus status, {VoidCallback? onStop}) =>
      PanelAction(
        id: id,
        title: title,
        description: description,
        details: details,
        icon: icon,
        onRun: onRun,
        onStop: onStop,
        status: status,
      );
}
