part of 'flutter_build_service.dart';

/// Where a [FlutterBuildService] command reports its progress.
class BuildOutput {
  /// Receives informational output lines.
  final ProcessOutputCallback onOutput;

  /// Receives error output lines.
  final ProcessOutputCallback onError;

  /// Clears previously reported errors before an automatic retry.
  final void Function() onResetErrors;

  /// Receives each started process so the caller can kill it.
  final void Function(Process process)? onProcessStarted;

  /// Creates an output sink from the caller's callbacks.
  const BuildOutput({
    required this.onOutput,
    required this.onError,
    required this.onResetErrors,
    this.onProcessStarted,
  });
}
