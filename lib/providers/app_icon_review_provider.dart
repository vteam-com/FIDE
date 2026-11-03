import 'package:fide/models/app_icon_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the App Icons view shows for the open project, checked again
/// after each save and fix and when another master image is picked; null
/// without a project.
final appIconReviewProvider = FutureProvider<AppIconReview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  ref.watch(savedFilesRevisionProvider);
  if (projectPath == null) return null;
  final masterPath = await ref.watch(appIconMasterProvider.future);
  return ref
      .read(appIconInspectorProvider)
      .review(projectPath, masterPath: masterPath);
});
