part of 'flutter_build_service.dart';

/// Where a [FlutterBuildService] command reports its progress.
class BuildOutput {
  /// Receives informational output lines.
  final ProcessOutputCallback onOutput;

  /// Receives error output lines.
  final ProcessOutputCallback onError;

  /// Receives each started process so the caller can kill it.
  final void Function(Process process)? onProcessStarted;

  /// Receives the session of an app [FlutterBuildService.run] runs, once
  /// the app has launched, so the caller can hot reload and stop it.
  final void Function(FlutterAppSession session)? onAppStarted;

  /// Creates an output sink from the caller's callbacks.
  const BuildOutput({
    required this.onOutput,
    required this.onError,
    this.onProcessStarted,
    this.onAppStarted,
  });
}
