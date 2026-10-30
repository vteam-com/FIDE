import 'dart:io';

import 'package:fide/models/code_coverage.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/build_artifacts_inspector.dart';
import 'package:fide/providers/code_review.dart';
import 'package:fide/providers/localization_service.dart';

/// Gathers a [ProjectOverview] from the services that already read each
/// part: fCheck through [CodeReview], ARB files through [ArbService] and
/// the app icon through [BuildArtifactsInspector].
class ProjectOverviewService {
  final CodeReview _codeReview;
  final ArbService _arbService;
  final BuildArtifactsInspector _inspector;

  /// Creates a service reading through the given services.
  const ProjectOverviewService(
    this._codeReview,
    this._arbService,
    this._inspector,
  );

  /// Reads the overview of the project at [projectPath], analyzing it
  /// with fCheck on a background isolate.
  Future<ProjectOverview> load(String projectPath) async {
    final paths = ProjectPaths(projectPath);
    final (code, arbFiles, appIconPath, coverage) = await (
      _codeReview.analyze(projectPath),
      _arbService.loadArbFiles(paths.l10nDir),
      _inspector.projectIconPath(projectPath),
      _readCoverage(paths.coverageLcov),
    ).wait;
    return ProjectOverview(
      appIconPath: appIconPath,
      code: code,
      languages: [for (final file in arbFiles.valid) file.languageCode],
      translations: _arbService.compareArbFiles(arbFiles.valid),
      coverage: coverage,
    );
  }

  /// Coverage from the lcov report at [lcovPath], or null when absent.
  Future<CodeCoverage?> _readCoverage(String lcovPath) async {
    final report = File(lcovPath);
    if (!await report.exists()) return null;
    return CodeCoverage.fromLcov(await report.readAsString());
  }
}
