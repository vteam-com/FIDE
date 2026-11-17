import 'package:fide/models/dart_analysis.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';

/// Runs `dart analyze` on a project: the compile errors, warnings and lints
/// the quality score's fCheck analysis does not check.
class DartAnalyzer {
  /// Creates an analyzer launching `dart` through [_runner].
  const DartAnalyzer(this._runner);

  final ProcessRunner _runner;

  /// Highest exit code of a run that analyzed the project: 0 when clean,
  /// up to 3 by the most serious problem found.
  static const int _maxAnalyzedExitCode = 3;

  /// What `dart analyze` finds in the project at [projectPath], with its
  /// output; throws when it does not analyze the project.
  Future<DartAnalysis> analyze(String projectPath) async {
    final result = await _runner.run(FlutterSdk.dartExecutable, [
      'analyze',
    ], workingDirectory: projectPath);
    final errors = '${result.stderr}'.trim();
    // Exits non-zero whenever it finds a problem
    if (result.exitCode > _maxAnalyzedExitCode) {
      throw Exception('dart analyze failed: $errors');
    }
    return DartAnalysis.parse(
      [
        '${result.stdout}'.trimRight(),
        if (errors.isNotEmpty) errors,
      ].join('\n'),
      rootPath: projectPath,
    );
  }
}
