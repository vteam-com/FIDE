part of 'flutter_build_service.dart';

/// A `flutter` step of a [FlutterBuildService] command that exited
/// non-zero; the panels word it for the log.
class BuildException implements Exception {
  /// The step that failed.
  final BuildStep step;

  /// The `flutter` arguments of the step, e.g. `pub get`.
  final String arguments;

  /// The step's exit code.
  final int exitCode;

  /// Creates the failure of [step], run as `flutter` [arguments], with
  /// [exitCode].
  const BuildException(this.step, this.arguments, this.exitCode);

  @override
  String toString() => 'flutter $arguments exited with $exitCode';
}
