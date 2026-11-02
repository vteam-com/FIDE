/// One project health check that can cost quality-score points.
enum HealthCheck {
  /// `pubspec.lock` is missing.
  missingLock,

  /// Build logs mention errors.
  buildErrors,

  /// Build logs mention warnings.
  buildWarnings,

  /// Files are over the large-file threshold.
  largeFiles,
}
