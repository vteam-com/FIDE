import 'package:fide/models/repeated_settings_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/repeated_settings_analyzer.dart';
import 'package:fide/services/serial_runs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [RepeatedSettingsAnalyzer] behind [repeatedSettingsReviewProvider]; override in
/// tests to fake the review.
final repeatedSettingsAnalyzerProvider = Provider<RepeatedSettingsAnalyzer>(
  (_) => const RepeatedSettingsAnalyzer(),
);

/// The reviews behind [repeatedSettingsReviewProvider], one at a time.
final _repeatedSettingsReviewRunsProvider = Provider<SerialRuns>(
  (_) => SerialRuns(),
);

/// What the Analyzer tab's Repeated Widget Settings review shows for the open project:
/// reviewed again once saves pause while the tab shows it, one review at
/// a time, and kept while other tabs do (a review takes seconds); null
/// without a project.
final repeatedSettingsReviewProvider = FutureProvider<RepeatedSettingsReview?>((
  ref,
) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  return afterSavesPause(
    ref,
    ref.read(_repeatedSettingsReviewRunsProvider),
    () async {
      final analyzer = ref.read(repeatedSettingsAnalyzerProvider);
      return analyzer.review(projectPath, await requireDartSdkPath(ref));
    },
  );
});
