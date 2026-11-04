part of 'flutter_build_service.dart';

/// A `flutter` command of a [FlutterBuildService] that exited non-zero;
/// the panels word it for the log.
class BuildException implements Exception {
  /// The `flutter` arguments of the command, e.g. `clean`.
  final String arguments;

  /// The command's exit code.
  final int exitCode;

  /// Creates the failure of `flutter` [arguments] with [exitCode].
  const BuildException(this.arguments, this.exitCode);

  @override
  String toString() => 'flutter $arguments exited with $exitCode';
}
