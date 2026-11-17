import 'package:fide/models/dry_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/dry_analyzer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [DryAnalyzer] behind [dryReviewProvider]; override in
/// tests to fake the review.
final dryAnalyzerProvider = Provider<DryAnalyzer>((_) => const DryAnalyzer());

/// What the Analyzer tab's DRY Review shows for the open project:
/// reviewed again after each save while the tab shows it, and kept while
/// other tabs do (a review takes seconds); null without a project.
final dryReviewProvider = FutureProvider<DryReview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  ref.watch(savedFilesRevisionProvider);
  if (projectPath == null) return null;
  final sdkPath = await ref.read(flutterSdkProvider).dartSdkPath();
  if (sdkPath == null) throw StateError('Flutter SDK not found');
  return ref.read(dryAnalyzerProvider).review(projectPath, sdkPath);
});
