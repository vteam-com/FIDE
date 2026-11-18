import 'package:fide/models/status_tone.dart';

/// Progress of a panel action (build, run, test...).
enum ActionStatus {
  /// Not started, or back to rest after showing a result.
  idle,

  /// In progress, starting up.
  running,

  /// In progress past its startup, such as an app that has launched and
  /// keeps running until stopped.
  live,

  /// Live, applying the saved code to the running app with a hot reload.
  reloading,

  /// Live, restarting the running app on the saved code (hot restart).
  restarting,

  /// Finished successfully.
  success,

  /// Failed or exited non-zero.
  error,
}

/// How a finished [ActionStatus] is shown, shared by every action list so
/// success and failure look the same everywhere.
extension ActionStatusResult on ActionStatus {
  /// Whether the action is working toward a result, as a progress ring
  /// shows: starting up, or a live app reloading or restarting.
  bool get isBusy => this == ActionStatus.running || isReloading;

  /// Whether the action is in progress: starting up, or [isLive].
  bool get isInProgress => this == ActionStatus.running || isLive;

  /// Whether the action is past its startup and runs until stopped,
  /// reloading or not.
  bool get isLive => this == ActionStatus.live || isReloading;

  /// Whether a live app is applying the saved code: a hot reload or
  /// restart.
  bool get isReloading =>
      this == ActionStatus.reloading || this == ActionStatus.restarting;

  /// [StatusTone.success] or [StatusTone.error] once finished; null while
  /// idle or in progress.
  StatusTone? get resultTone => switch (this) {
    ActionStatus.success => StatusTone.success,
    ActionStatus.error => StatusTone.error,
    _ => null,
  };

  /// A one-word name of the result; null while idle or in progress.
  String? get resultLabel => switch (this) {
    ActionStatus.success => 'Success',
    ActionStatus.error => 'Failed',
    _ => null,
  };
}
