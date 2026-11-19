import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/dart_analysis.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/models/project_quality.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:fide/services/serial_runs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

/// Watches the open project's saves, counted by [revision] (every save
/// by default), and, after one, waits for saves to pause, so a burst of
/// them is analyzed once; false when a newer save superseded this run,
/// whose result is then dropped.
Future<bool> savesPaused(Ref ref, {StateProvider<int>? revision}) async {
  if (ref.watch(revision ?? savedFilesRevisionProvider) == 0) return true;
  await Future<void>.delayed(AppDuration.saveBurstPause);
  return ref.mounted;
}

/// Runs [task] for the provider building with [ref] once saves pause (see
/// [savesPaused]) and the run before it on [runs] ended; null when a newer
/// save or refresh superseded this run before it started or while it ran.
/// [revision] picks the saves that count, as for [savesPaused].
Future<T?> afterSavesPause<T>(
  Ref ref,
  SerialRuns runs,
  Future<T> Function() task, {
  StateProvider<int>? revision,
}) async {
  if (!await savesPaused(ref, revision: revision)) return null;
  return runs.run(task, isCurrent: () => ref.mounted);
}

/// The fCheck runs behind [projectOverviewProvider], one at a time.
final _overviewRunsProvider = Provider<SerialRuns>((_) => SerialRuns());

/// The health checks behind [healthIndicatorsProvider], one at a time.
final _healthRunsProvider = Provider<SerialRuns>((_) => SerialRuns());

/// When the analysis behind [projectOverviewProvider]'s latest result
/// started, by project folder; files changed since are not in it.
final _overviewStartsProvider = Provider<Map<String, DateTime>>((_) => {});

/// The center panel's overview of the current project, or null without
/// one; re-analyzed once saves pause, the next time it is shown, one
/// analysis at a time.
final projectOverviewProvider = FutureProvider<ProjectOverview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  return afterSavesPause(ref, ref.read(_overviewRunsProvider), () async {
    final started = DateTime.now();
    final overview = await ref
        .read(projectOverviewServiceProvider)
        .load(projectPath);
    if (ref.mounted) ref.read(_overviewStartsProvider)[projectPath] = started;
    return overview;
  });
});

/// Hands the overview's fCheck analysis, made with fCheck's default
/// settings, to the quick fixes and the AI reviews, so they analyze the
/// project again only when a file changed since: after the editor or a
/// fix saved one, the overview analyzing it again is awaited; when one
/// changed on disk, or the folder isn't the open project, there is none.
final savedCodeMetricsProvider = Provider<LatestCodeMetrics>(
  (ref) => (projectPath) async {
    if (ref.read(currentProjectPathProvider) != projectPath) return null;
    final ProjectOverview? overview;
    try {
      overview = await ref.read(projectOverviewProvider.future);
    } on Object {
      return null;
    }
    final started = ref.read(_overviewStartsProvider)[projectPath];
    if (overview == null || started == null) return null;
    return await _changedSince(projectPath, started) ? null : overview.code;
  },
);

/// Whether a file of the project at [projectPath] changed after [time].
Future<bool> _changedSince(String projectPath, DateTime time) async {
  try {
    await for (final entity in ProjectFiles.entities(projectPath)) {
      if ((await entity.stat()).modified.isAfter(time)) return true;
    }
    return false;
  } on FileSystemException {
    return true;
  }
}

/// What `dart analyze` finds in the current project, or null without
/// one; run again once saves pause, the next time it is read, stopping
/// the run a newer save made stale.
final dartAnalysisProvider = FutureProvider<DartAnalysis?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (!await savesPaused(ref) || projectPath == null) return null;
  final stale = Completer<void>();
  ref.onDispose(stale.complete);
  return ref
      .read(dartAnalyzerProvider)
      .analyze(projectPath, stop: stale.future);
});

/// The `dart analyze` run whose output the Info panel cleared, hidden
/// there until the next run; null when none is. The run itself stays, as
/// the health checks read it.
final clearedDartAnalysisProvider = StateProvider<DartAnalysis?>((_) => null);

/// The open project's health checks, or null without one; run again once
/// saves pause, one run at a time.
final healthIndicatorsProvider = FutureProvider<HealthIndicators?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  return afterSavesPause(
    ref,
    ref.read(_healthRunsProvider),
    () => ref.read(healthCheckerProvider).check(projectPath),
  );
});

/// The open project's quality: fCheck's score less what `dart analyze`'s
/// diagnostics cost, over the issues of fCheck, `dart analyze` (errors
/// first) and the health checks;
/// null until fCheck has analyzed the project. `dart analyze` adds its
/// issues once it is done.
final projectQualityProvider = Provider<ProjectQuality?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  final code = ref.watch(projectOverviewProvider).value?.code;
  if (projectPath == null || code == null) return null;
  final dart = ref.watch(dartAnalysisProvider);
  final deduction = dart.hasError ? 0 : dart.value?.deduction ?? 0;
  return ProjectQuality(
    score: (code.complianceScore - deduction).clamp(0, AppMetric.maxScore),
    issues: [
      // A failed run keeps the last one's value: show the failure alone
      if (dart.error case final error?)
        QualityIssue(
          label: '${DartAnalysis.title} did not run',
          tone: StatusTone.info,
          guidance: '$error',
        )
      else
        ...?dart.value?.issues,
      ...code.qualityIssues,
      ...?ref.watch(healthIndicatorsProvider).value?.issues(projectPath),
    ],
  );
});

/// The analyses the open project's quality is made of: fCheck's overview,
/// `dart analyze` and the health checks.
final List<FutureProvider<Object?>> _qualitySources = [
  projectOverviewProvider,
  dartAnalysisProvider,
  healthIndicatorsProvider,
];

/// Whether one of the analyses of the open project's quality runs, so the
/// quality is about to change.
final projectQualityBusyProvider = Provider<bool>(
  (ref) => _qualitySources.any((source) => ref.watch(source).isLoading),
);

/// Invalidates a provider, as `Ref.invalidate` and `WidgetRef.invalidate`
/// do.
typedef ProviderInvalidate = void Function(ProviderOrFamily provider);

/// Runs every analysis of the open project's quality again, from a widget
/// or a provider passing its `ref.invalidate`.
void refreshProjectQuality(ProviderInvalidate invalidate) {
  for (final source in _qualitySources) {
    invalidate(source);
  }
}

/// Every issue of the open project's quality, as the editor marks them in
/// its files, or null until fCheck has analyzed it; listening to it
/// re-analyzes after each save.
final qualityIssuesProvider = Provider<List<QualityIssue>?>(
  (ref) => ref.watch(projectQualityProvider)?.issues,
);

/// The open project's hardcoded-string and localization issues, or null
/// until the overview is analyzed.
final stringIssuesProvider = Provider<List<QualityIssue>?>(
  (ref) => ref.watch(projectOverviewProvider).value?.code.stringIssues,
);

/// The open project's string findings, flagged on the Localize tab; an
/// issue without listed findings counts once.
final stringIssueCountProvider = Provider<int>(
  (ref) => (ref.watch(stringIssuesProvider) ?? const []).fold(
    0,
    (sum, issue) => sum + math.max(issue.findings.length, 1),
  ),
);
