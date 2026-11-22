import 'dart:isolate';

import 'package:fide/models/file_layout_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/file_layout_analyzer.dart';
import 'package:fide/services/serial_runs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [FileLayoutAnalyzer] behind [fileLayoutReviewProvider];
/// override in tests to fake the review.
final fileLayoutAnalyzerProvider = Provider<FileLayoutAnalyzer>(
  (_) => const FileLayoutAnalyzer(),
);

/// The reviews behind [fileLayoutReviewProvider], one at a time.
final _fileLayoutRunsProvider = Provider<SerialRuns>((_) => SerialRuns());

/// What the Analyzer tab's File Layout review shows for the open project:
/// reviewed again once saves pause, one review at a time, off the UI
/// thread, and kept while other tabs show; null without a project.
final fileLayoutReviewProvider = FutureProvider<FileLayoutReview?>((ref) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  final analyzer = ref.read(fileLayoutAnalyzerProvider);
  return afterSavesPause(
    ref,
    ref.read(_fileLayoutRunsProvider),
    () => Isolate.run(() => analyzer.analyze(projectPath)),
  );
});
