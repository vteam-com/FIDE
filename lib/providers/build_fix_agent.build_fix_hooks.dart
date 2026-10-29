part of 'build_fix_agent.dart';

/// Callbacks a [BuildFixAgent] runs as it works, so the caller can show
/// progress, refresh what the edits touch and rebuild the project.
class BuildFixHooks {
  /// Receives a one-line description of each skill the model runs.
  final void Function(String step) onStep;

  /// Runs after a skill writes the file at this absolute path.
  final Future<void> Function(String path) onFileWritten;

  /// Rebuilds the project; completes with the build's error output, empty
  /// when the build succeeds.
  final Future<String> Function() checkBuild;

  /// Creates hooks from the caller's callbacks.
  const BuildFixHooks({
    required this.onStep,
    required this.onFileWritten,
    required this.checkBuild,
  });
}
