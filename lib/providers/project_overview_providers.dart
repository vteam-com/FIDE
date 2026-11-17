import 'dart:math' as math;

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/dart_analysis.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/models/project_quality.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/project_metrics_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The center panel's overview of the current project, or null without
/// one; re-analyzed after a save the next time it is shown.
final projectOverviewProvider = FutureProvider<ProjectOverview?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  ref.watch(savedFilesRevisionProvider);
  if (projectPath == null) return null;
  return ref.read(projectOverviewServiceProvider).load(projectPath);
});

/// What `dart analyze` finds in the current project, or null without
/// one; run again after a save the next time it is read.
final dartAnalysisProvider = FutureProvider<DartAnalysis?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  ref.watch(savedFilesRevisionProvider);
  if (projectPath == null) return null;
  return ref.read(dartAnalyzerProvider).analyze(projectPath);
});

/// The open project's quality: fCheck's score less what `dart analyze`'s
/// diagnostics cost, over the issues of fCheck, `dart analyze` (errors
/// first) and the health checks of the Info tab;
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
      ...?ref.watch(projectMetricsProvider).health?.issues(projectPath),
    ],
  );
});

/// Whether the overview or `dart analyze` is analyzing the open project,
/// so the project's quality is about to change.
final projectQualityBusyProvider = Provider<bool>(
  (ref) =>
      ref.watch(projectOverviewProvider).isLoading ||
      ref.watch(dartAnalysisProvider).isLoading,
);

/// Analyzes the open project's quality again: fCheck's overview and
/// `dart analyze`.
void refreshProjectQuality(WidgetRef ref) => ref
  ..invalidate(projectOverviewProvider)
  ..invalidate(dartAnalysisProvider);

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
