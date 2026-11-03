import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/app_icon_inspector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The app icon of the project at the given folder, or null without one;
/// looked up once per folder and kept, so the title bar and the recent
/// projects menu show it without touching the disk again.
final projectIconPathProvider = FutureProvider.family<String?, String>(
  (ref, projectPath) =>
      ref.read(buildArtifactsInspectorProvider).projectIconPath(projectPath),
);

/// Provides the [AppIconInspector] behind [appIconReviewProvider]; override
/// in tests to fake the check.
final appIconInspectorProvider = Provider<AppIconInspector>(
  (_) => const AppIconInspector(),
);

/// The image the user picked to generate the open project's icons from;
/// null for the default. Forgotten when the project changes.
final appIconMasterChoiceProvider = StateProvider<String?>((ref) {
  ref.watch(currentProjectPathProvider);
  return null;
});

/// The app icon file picked in the App Icons view, as an absolute path,
/// whose details the Outline tab shows while the view is open; null when
/// none is. Forgotten when the project changes.
final appIconSelectionProvider = StateProvider<String?>((ref) {
  ref.watch(currentProjectPathProvider);
  return null;
});

/// The image the open project's icons are generated from: the one the
/// user picked, else the fixer's default; null when there is none.
final appIconMasterProvider = FutureProvider<String?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  final choice = ref.watch(appIconMasterChoiceProvider);
  if (projectPath == null || choice != null) return choice;
  return ref.read(appIconFixerProvider).defaultMasterPath(projectPath);
});
