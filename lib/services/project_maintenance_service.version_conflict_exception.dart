part of 'project_maintenance_service.dart';

/// Pub could not resolve the dependencies after an upgrade.
class VersionConflictException extends MaintenanceException {
  /// Creates a conflict explained by [summary], blaming [package] when pub
  /// names one.
  const VersionConflictException(super.summary, this.package);

  /// Pub's marker for a failed resolution.
  static const String versionSolvingFailed = 'version solving failed';

  /// What pub says when it doesn't explain the failure.
  static const String _unexplainedConflict = 'Dependency conflict detected';

  /// Start of pub's advice lines, which don't explain the failure.
  static const String _advicePrefix = '* Consider';

  /// The pattern of "X depends on both `<package>`" lines naming the
  /// package in conflict.
  static final RegExp _blamedPackage = RegExp(r'\S+ depends on both (\w+) ');

  /// The package pub blames, from "X depends on both `<package>`"; null
  /// when pub names none.
  final String? package;

  /// A conflict's one-line explanation, [MaintenanceException.message].
  String get summary => message;

  /// Whether pub's [error] output reports a failed resolution.
  static bool isConflict(String error) => error.contains(versionSolvingFailed);

  /// Summarizes pub's version-solving [error]: the first explanatory line
  /// after the failure marker, and the package named in "X depends on both
  /// `<package>`" when pub reports one.
  factory VersionConflictException.fromPubError(String error) {
    final lines = error.split('\n').map((line) => line.trim()).toList();
    final failureLine = lines.indexWhere(
      (line) => line.contains('$versionSolvingFailed.'),
    );
    final summary = failureLine == -1
        ? null
        : lines
              .skip(failureLine + 1)
              .where(
                (line) => line.isNotEmpty && !line.startsWith(_advicePrefix),
              )
              .firstOrNull;
    return VersionConflictException(
      summary ?? _unexplainedConflict,
      _blamedPackage.firstMatch(error)?.group(1),
    );
  }
}
