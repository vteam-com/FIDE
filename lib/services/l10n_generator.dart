import 'package:fide/services/process_runner.dart';

/// Generates a project's localization classes with `flutter gen-l10n`.
class L10nGenerator {
  final ProcessRunner _runner;

  /// Creates a generator launching `flutter` through [_runner].
  const L10nGenerator(this._runner);

  /// Runs `flutter gen-l10n` in the project at [projectPath], throwing with
  /// the tool's stderr on failure.
  Future<void> generateClasses(String projectPath) async {
    final result = await _runner.run('flutter', [
      'gen-l10n',
    ], workingDirectory: projectPath);
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to generate localization classes: ${result.stderr}',
      );
    }
  }
}
