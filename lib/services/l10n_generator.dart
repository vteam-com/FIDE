import 'dart:io';

import 'package:fide/models/l10n_config.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';

/// Generates a project's localization classes with `flutter gen-l10n`.
class L10nGenerator {
  final ProcessRunner _runner;

  /// Creates a generator launching `flutter` through [_runner].
  const L10nGenerator(this._runner);

  /// Runs `flutter gen-l10n` in the project at [projectPath], throwing with
  /// the tool's stderr on failure.
  Future<void> generateClasses(String projectPath) async {
    await _runner.runChecked(
      FlutterSdk.executable,
      ['gen-l10n'],
      workingDirectory: projectPath,
      error: (result) => Exception(
        'Failed to generate localization classes: ${result.stderr}',
      ),
    );
  }

  /// Writes [arb] as the template ARB file of the project at
  /// [projectPath], whose gen-l10n settings are [config], then generates
  /// the classes again so its new keys can be looked up.
  Future<void> writeTemplate(
    String projectPath,
    L10nConfig config,
    Map<String, dynamic> arb,
  ) async {
    await File(config.templatePathIn(projectPath))
        .writeAsString(ArbService.encode(arb));
    await generateClasses(projectPath);
  }
}
