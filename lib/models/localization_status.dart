/// Where a project stands in its localization setup; picks which view the
/// Localization panel shows.
enum LocalizationStatus {
  /// The project's files are being inspected.
  checking,

  /// The folder has no pubspec.yaml.
  noProject,

  /// The pubspec doesn't declare a Flutter project.
  notFlutterProject,

  /// No localization piece is in place yet.
  notStarted,

  /// Some localization pieces are in place, others are missing.
  partial,

  /// ARB files, generated classes and app integration are all in place.
  complete,

  /// Inspecting the project failed.
  error,
}
