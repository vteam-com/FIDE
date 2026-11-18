import 'dart:async';

import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/project_info_state.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/project_analyzer.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The actions of the Info and Run panels on the open project; a new
/// controller per project, which measures it at once, dropped with the
/// panels.
final projectInfoControllerProvider =
    StateNotifierProvider.autoDispose<ProjectInfoController, ProjectInfoState>((
      ref,
    ) {
      final controller = ProjectInfoController(
        ref.watch(currentProjectPathProvider),
        analyzer: ref.read(projectAnalyzerProvider),
        maintenance: ref.read(projectMaintenanceServiceProvider),
        entries: ref.read(fileEntryServiceProvider),
        metrics: ref.read(projectMetricsProvider.notifier),
        currentMetrics: () => ref.read(projectMetricsProvider),
      );
      // Marking it busy must wait for the build creating it; a failure
      // leaves the cached metrics shown
      unawaited(Future.microtask(controller.analyze));
      return controller;
    });

/// Reads the metrics the Info panel shows now.
typedef MetricsReader = ProjectMetrics Function();

/// Measures and upgrades the open project for the Info and Run panels,
/// writing the metrics it measures and keeping what pub reported; each
/// action marks the state busy until it ends, whether it succeeds or fails.
class ProjectInfoController extends StateNotifier<ProjectInfoState>
    with ProjectActions<ProjectInfoState> {
  final ProjectAnalyzer _analyzer;

  final MetricsReader _currentMetrics;

  final FileEntryService _entries;

  final ProjectMaintenanceService _maintenance;

  final ProjectMetricsNotifier _metrics;

  @override
  final String? projectPath;

  /// Creates a controller for the project at [projectPath], measuring it
  /// with [analyzer], maintaining it with [maintenance], checking its
  /// files with [entries], and showing what it measures through
  /// [metrics], whose current value [currentMetrics] reads.
  ProjectInfoController(
    String? projectPath, {
    required ProjectAnalyzer analyzer,
    required ProjectMaintenanceService maintenance,
    required FileEntryService entries,
    required ProjectMetricsNotifier metrics,
    required MetricsReader currentMetrics,
  }) : this._(
         projectPath,
         analyzer,
         maintenance,
         entries,
         metrics,
         currentMetrics,
       );

  ProjectInfoController._(
    this.projectPath,
    this._analyzer,
    this._maintenance,
    this._entries,
    this._metrics,
    this._currentMetrics,
  ) : super(ProjectInfoState.initial);

  /// The project's `pubspec.yaml`; null when there is none to open.
  String? get pubspecPath {
    final projectPath = this.projectPath;
    if (projectPath == null) return null;
    final path = ProjectPaths(projectPath).pubspec;
    return _entries.exists(path) ? path : null;
  }

  /// Measures the project again and shows the result; null when it
  /// worked, as there is nothing to tell.
  Future<ActionOutcome?> analyze() {
    return runAction('Failed to analyze project', _analyzing, (
      projectPath,
    ) async {
      final metrics = await _analyzer.analyze(projectPath);
      await _metrics.updateMetrics(projectPath, metrics);
      return null;
    });
  }

  /// Runs `flutter pub outdated`, keeping what it printed and showing the
  /// outdated packages in the metrics.
  Future<ActionOutcome?> checkOutdated() {
    return runAction('Failed to check outdated', _checkingOutdated, (
      projectPath,
    ) async {
      final report = await _maintenance.outdatedReport(projectPath);
      updateState(
        (state) =>
            state.copyWith(outdatedOutput: report.output, clearConflict: true),
      );
      await _metrics.updateMetrics(
        projectPath,
        _currentMetrics().copyWith(outdated: report.packages),
      );
      return const ActionOutcome.success('Outdated check completed');
    });
  }

  /// Raises the dependency constraints to their latest resolvable
  /// versions and measures the project again; a resolution pub cannot
  /// make is kept as the conflict to show, blaming the package it names.
  Future<ActionOutcome?> upgradePackages() {
    return runAction('Error upgrading packages', _upgrading, (
      projectPath,
    ) async {
      updateState(
        (state) =>
            state.copyWith(clearConflict: true, problematicPackages: const {}),
      );
      try {
        final upgraded = await _maintenance.upgradeToResolvable(projectPath);
        final failure = await analyze();
        if (failure != null) return failure;
        return upgraded.isNotEmpty
            ? const ActionOutcome.success(
                'Packages upgraded to compatible versions!',
              )
            : const ActionOutcome.info(
                'All packages already up to date with compatible versions.',
              );
      } on VersionConflictException catch (conflict) {
        updateState(
          (state) => state.copyWith(
            conflictSummary: conflict.summary,
            problematicPackages: {
              ...state.problematicPackages,
              ?conflict.package,
            },
          ),
        );
        return const ActionOutcome.failure(
          'Package upgrade failed due to dependency conflicts',
        );
      }
    });
  }

  /// Marks the analysis running or done.
  static ProjectInfoState _analyzing(ProjectInfoState state, bool busy) =>
      state.copyWith(isAnalyzing: busy);

  /// Marks the outdated check running or done.
  static ProjectInfoState _checkingOutdated(
    ProjectInfoState state,
    bool busy,
  ) => state.copyWith(isCheckingOutdated: busy);

  /// Marks the upgrade running or done.
  static ProjectInfoState _upgrading(ProjectInfoState state, bool busy) =>
      state.copyWith(isUpgrading: busy);
}
