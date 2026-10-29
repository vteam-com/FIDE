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
