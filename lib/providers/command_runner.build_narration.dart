part of 'command_runner.dart';

/// The line the log shows for the [BuildException] of a failed
/// `FlutterBuildService` command.
abstract final class BuildNarration {
  /// The failed `flutter` command of [failure], as the log reports it.
  static String failed(BuildException failure) =>
      'Flutter ${failure.arguments} failed with exit code ${failure.exitCode}';
}
