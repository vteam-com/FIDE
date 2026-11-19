import 'package:fide/models/dry_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/dry_analyzer.dart';
import 'package:fide/services/serial_runs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [DryAnalyzer] behind [dryReviewProvider]; override in
/// tests to fake the review.
final dryAnalyzerProvider = Provider<DryAnalyzer>((_) => const DryAnalyzer());

/// The reviews behind [dryReviewProvider], one at a time.
final _dryReviewRunsProvider = Provider<SerialRuns>((_) => SerialRuns());

/// What the Analyzer tab's Repeated Widget Settings review shows for the open project:
/// reviewed again once saves pause while the tab shows it, one review at
/// a time, and kept while other tabs do (a review takes seconds); null
/// without a project.
final dryReviewProvider = FutureProvider<DryReview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  return afterSavesPause(ref, ref.read(_dryReviewRunsProvider), () async {
    final analyzer = ref.read(dryAnalyzerProvider);
    final sdkPath = await ref.read(dartSdkPathProvider.future);
    if (sdkPath == null) {
      // Look again next time, in case Flutter was installed meanwhile
      if (ref.mounted) ref.invalidate(dartSdkPathProvider);
      throw StateError('Flutter SDK not found');
    }
    return analyzer.review(projectPath, sdkPath);
  });
});
