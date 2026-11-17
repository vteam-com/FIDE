import 'package:fide/models/app_icon_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/serial_runs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The checks behind [appIconReviewProvider], one at a time.
final _appIconReviewRunsProvider = Provider<SerialRuns>((_) => SerialRuns());

/// What the App Icons view shows for the open project, checked again
/// once saves of files other than Dart source pause (a code edit can't
/// change an icon), one check at a time, and when another master image
/// is picked; null without a project.
final appIconReviewProvider = FutureProvider<AppIconReview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  final masterPath = ref.watch(appIconMasterProvider.future);
  return afterSavesPause(
    ref,
    ref.read(_appIconReviewRunsProvider),
    () async => ref
        .read(appIconInspectorProvider)
        .review(projectPath, masterPath: await masterPath),
    revision: savedAssetsRevisionProvider,
  );
});
