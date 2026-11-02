import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_files.dart';
import 'package:path/path.dart' as p;

/// Runs fcheck on a project, on a background isolate: the analysis behind
/// the AI reviews, the overview and the quick fixes, and fcheck's member
/// sorter.
class CodeReview {
  /// Creates a stateless fcheck runner.
  const CodeReview();

  /// Analyzes the project at [projectPath] with fcheck, honoring its
  /// `.fcheck` file like the CLI, on a background isolate.
  ///
  /// [nearDuplicates] loosens duplicate detection to
  /// [AppMetric.aiReviewDuplicateSimilarity] so the review also sees code
  /// that was copied and has since drifted.
  Future<fcheck.ProjectMetrics> analyze(
    String projectPath, {
    bool nearDuplicates = false,
  }) => Isolate.run(
    () => fcheck.AnalyzeFolder.fromConfig(
      fcheck.FcheckConfig.loadForInputDirectory(Directory(projectPath)),
      duplicateCodeSimilarityThreshold: nearDuplicates
          ? AppMetric.aiReviewDuplicateSimilarity
          : null,
      duplicateCodeMinNonEmptyLineCount: nearDuplicates
          ? AppMetric.aiReviewDuplicateMinLines
          : null,
    ).analyze(),
  );

  /// Sorts the members of widget and `State` classes, and the imports, of
  /// the project at [projectPath] with fcheck's own sorter, honoring its `.fcheck` file, on a
  /// background isolate, and returns the paths of the files it rewrote.
  ///
  /// Only the sorting analyzer runs, so fcheck's other fixes, such as
  /// rewriting ARB files, don't.
  Future<List<String>> sortMembers(String projectPath) => Isolate.run(() {
    final config = fcheck.FcheckConfig.loadForInputDirectory(
      Directory(projectPath),
    );
    final root = config.analysisDirectory;
    final before = {
      for (final entity in root.listSync(recursive: true, followLinks: false))
        if (entity is File &&
            p.extension(entity.path) == '.dart' &&
            !ProjectFiles.isSkippedPath(
              p.relative(entity.path, from: root.path),
            ))
          entity.path: entity.readAsStringSync(),
    };
    fcheck.AnalyzeFolder(
      root,
      fix: true,
      excludePatterns: config.mergeExcludePatterns(const []),
      enabledAnalyzers: const {fcheck.AnalyzerDomain.sourceSorting},
    ).analyze();
    return [
      for (final MapEntry(key: path, value: content) in before.entries)
        if (File(path).readAsStringSync() != content) path,
    ];
  });
}
