import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:path/path.dart' as p;

/// Removes the ARB keys fCheck found unused, without AI: from every ARB
/// file of the project with their `@key` metadata, then regenerates the
/// localizations classes.
class ArbKeyRemover {
  /// Creates a remover reading project settings with [_config] and
  /// regenerating through [_generator].
  const ArbKeyRemover(this._config, this._generator);

  final ProjectConfigReader _config;

  final L10nGenerator _generator;

  /// The keys [metrics] found unused, once each, in report order.
  static List<String> unusedKeys(fcheck.ProjectMetrics metrics) => {
    for (final issue in metrics.localizationIssues)
      for (final detail in issue.details)
        if (QuickFix.removeUnusedKeys.localizationProblems.contains(
          detail.problemType.name,
        ))
          detail.key,
  }.toList();

  /// Removes [keys] and their metadata from the ARB files of the project
  /// at [projectPath] and regenerates its classes.
  Future<StringRewrite> apply(String projectPath, List<String> keys) async {
    final config = await _config.l10nConfig(projectPath);
    final prefix = config.templateParts?.prefix ?? '';
    final paths = [
      for (final path in await ArbService.arbFilesIn(
        config.arbDirIn(projectPath),
      ))
        if (p.basename(path).startsWith(prefix)) path,
    ];
    final removed = <String>{};
    final changedFiles = <String>[];
    for (final path in paths) {
      final arb = await ArbService.read(path);
      if (arb == null) continue;
      final found = keys.where(arb.containsKey).toList();
      if (found.isEmpty) continue;
      for (final key in found) {
        arb
          ..remove(key)
          ..remove('@$key');
      }
      await ArbService.write(path, arb);
      removed.addAll(found);
      changedFiles.add(path);
    }
    if (changedFiles.isNotEmpty) {
      await _generator.generateClasses(projectPath);
    }
    return StringRewrite(
      action: 'Removed',
      rewritten: removed.length,
      changedFiles: changedFiles,
      skipped: const {},
    );
  }
}
