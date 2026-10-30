import 'package:fide/models/status_tone.dart';

/// Progress of a panel action (build, run, test...).
enum ActionStatus {
  /// Not started, or back to rest after showing a result.
  idle,

  /// In progress.
  running,

  /// Finished successfully.
  success,

  /// Failed or exited non-zero.
  error,
}

/// How a finished [ActionStatus] is shown, shared by every action list so
/// success and failure look the same everywhere.
extension ActionStatusResult on ActionStatus {
  /// [StatusTone.success] or [StatusTone.error] once finished; null while
  /// idle or running.
  StatusTone? get resultTone => switch (this) {
    ActionStatus.success => StatusTone.success,
    ActionStatus.error => StatusTone.error,
    _ => null,
  };

  /// A one-word name of the result; null while idle or running.
  String? get resultLabel => switch (this) {
    ActionStatus.success => 'Success',
    ActionStatus.error => 'Failed',
    _ => null,
  };
}
