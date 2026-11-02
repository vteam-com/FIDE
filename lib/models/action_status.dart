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

  /// Finished successfully.
  success,

  /// Failed or exited non-zero.
  error,
}

/// How a finished [ActionStatus] is shown, shared by every action list so
/// success and failure look the same everywhere.
extension ActionStatusResult on ActionStatus {
  /// Whether the action is in progress, starting up or [ActionStatus.live].
  bool get isInProgress =>
      this == ActionStatus.running || this == ActionStatus.live;

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
