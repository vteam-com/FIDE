import 'dart:async';
import 'dart:math' as math;

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/dart_analysis.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/models/project_quality.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Watches the open project's saves and, after one, waits for saves to
/// pause, so a burst of them is analyzed once; false when a newer save
/// superseded this run, whose result is then dropped.
Future<bool> _savesPaused(Ref ref) async {
  if (ref.watch(savedFilesRevisionProvider) == 0) return true;
  await Future<void>.delayed(AppDuration.saveBurstPause);
  return ref.mounted;
}

/// The center panel's overview of the current project, or null without
/// one; re-analyzed once saves pause, the next time it is shown.
final projectOverviewProvider = FutureProvider<ProjectOverview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (!await _savesPaused(ref) || projectPath == null) return null;
  return ref.read(projectOverviewServiceProvider).load(projectPath);
});

/// What `dart analyze` finds in the current project, or null without
/// one; run again once saves pause, the next time it is read, stopping
/// the run a newer save made stale.
final dartAnalysisProvider = FutureProvider<DartAnalysis?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (!await _savesPaused(ref) || projectPath == null) return null;
  final stale = Completer<void>();
  ref.onDispose(stale.complete);
  return ref
      .read(dartAnalyzerProvider)
      .analyze(projectPath, stop: stale.future);
});

/// The open project's health checks, or null without one; run again once
/// saves pause.
final healthIndicatorsProvider = FutureProvider<HealthIndicators?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (!await _savesPaused(ref) || projectPath == null) return null;
  return ref.read(healthCheckerProvider).check(projectPath);
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
