import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/providers/project_service.dart';
import 'package:fide/providers/project_state_sink.dart';
import 'package:fide/providers/quick_fix_runner.dart';
import 'package:fide/providers/reference_finder.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/string_lookup_passer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

export 'package:fide/models/loading_action.dart';

part 'mru_folders_notifier.dart';
part 'open_documents_notifier.dart';
part 'project_manager.dart';
part 'project_metrics_notifier.dart';
part 'provider_project_state_sink.dart';
part 'selected_platform_notifier.dart';

// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((_) {
  return SharedPreferences.getInstance();
});

// State management for the selected file
final selectedFileProvider = StateProvider<FileSystemItem?>((_) => null);

// State management for project loading
final projectLoadedProvider = StateProvider<bool>((_) => false);

// State management for current project path
final currentProjectPathProvider = StateProvider<String?>((_) => null);

/// Error output of the last failed Execute panel action; empty once an
/// action succeeds. The AI panel's Fix Build sends it to the model.
final lastBuildErrorsProvider = StateProvider<String>((_) => '');

// State management for current project root
final currentProjectRootProvider = StateProvider<ProjectNode?>((_) => null);

/// Finds where the open project uses a declaration; null while no project
/// is open. Its background analysis stops when the project closes.
final referenceFinderProvider = Provider<ReferenceFinder?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  final finder = ReferenceFinder(
    projectPath: projectPath,
    flutterSdk: ref.read(flutterSdkProvider),
  );
  ref.onDispose(finder.dispose);
  return finder;
});

/// Provides the [StringLookupPasser] behind the Pass a lookup quick fix,
/// resolving the open project.
final stringLookupPasserProvider = Provider<StringLookupPasser>(
  (ref) => StringLookupPasser(
    ref.watch(referenceFinderProvider),
    ref.read(localizationServiceProvider),
    ref.read(codeFormatterProvider),
  ),
);

/// Provides the [QuickFixRunner] behind the issue dialogs' quick fixes and
/// the AI's `run_quick_fix` hook.
final quickFixRunnerProvider = Provider<QuickFixRunner>(
  (ref) => QuickFixRunner(
    review: ref.read(codeReviewProvider),
    localizer: ref.read(stringLocalizerProvider),
    lookups: ref.watch(stringLookupPasserProvider),
    extractor: ref.read(stringConstantsExtractorProvider),
    translator: ref.read(arbTranslatorProvider),
    migrator: ref.read(arbMigratorProvider),
    keyRemover: ref.read(arbKeyRemoverProvider),
  ),
);

/// Bumped each time the current project tree changes in place (Git status,
/// file system events), so tree views rebuild even though the root object is
/// the same.
final projectTreeRevisionProvider = StateProvider<int>((_) => 0);

// State management for project loading state
final projectLoadingProvider = StateProvider<bool>((_) => false);

/// Recently opened project folders, newest first; see [MruFoldersNotifier].
final mruFoldersProvider =
    StateNotifierProvider<MruFoldersNotifier, List<String>>(
      (ref) => MruFoldersNotifier(ref),
    );

/// The recent project folders that exist, recomputed only when the list
/// changes rather than on every build that shows them.
final accessibleMruFoldersProvider = Provider<Set<String>>(
  (ref) => {
    for (final folder in ref.watch(mruFoldersProvider))
      if (Directory(folder).existsSync()) folder,
  },
);

/// The app icon of the project at the given folder, or null without one;
/// looked up once per folder and kept, so the title bar and the recent
/// projects menu show it without touching the disk again.
final projectIconPathProvider = FutureProvider.family<String?, String>(
  (ref, projectPath) =>
      ref.read(buildArtifactsInspectorProvider).projectIconPath(projectPath),
);

/// The Execute panel's build target.
final selectedPlatformProvider =
    StateNotifierProvider<SelectedPlatformNotifier, FlutterPlatform>(
      (ref) => SelectedPlatformNotifier(ref),
    );

// Unified project manager provider
final projectManagerProvider = Provider<ProjectManager>((ref) {
  return ProjectManager(ref);
});

// Project service provider for complete project management
final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(
    _ProviderProjectStateSink(ref),
    ref.read(gitServiceProvider),
    ref.read(fileSystemWatcherProvider),
    loadTree: ref.read(projectTreeLoaderProvider),
  );
});

// State management for project creation errors
final projectCreationErrorProvider = StateProvider<String?>(
  (_ /*ref*/) => null,
);

// State management for loading actions log
final loadingActionsProvider = StateProvider<List<LoadingAction>>(
  (_ /*ref*/) => [],
);

/// The editor's open documents and active tab.
final openDocumentsProvider =
    StateNotifierProvider<OpenDocumentsNotifier, OpenDocuments>(
      (ref) => OpenDocumentsNotifier(
        onSaved: () => ref.read(savedFilesRevisionProvider.notifier).state++,
      ),
    );

/// Bumped each time the editor saves a file, so views derived from file
/// contents can refresh.
final savedFilesRevisionProvider = StateProvider<int>((_) => 0);

/// The center panel's overview of the current project, or null without
/// one; re-analyzed after a save the next time it is shown.
final projectOverviewProvider = FutureProvider<ProjectOverview?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  ref.watch(savedFilesRevisionProvider);
  if (projectPath == null) return null;
  return ref.read(projectOverviewServiceProvider).load(projectPath);
});

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

/// The document showing in the editor, or null.
final activeDocumentProvider = Provider<DocumentState?>(
  (ref) => ref.watch(openDocumentsProvider).active,
);

final projectMetricsProvider =
    StateNotifierProvider<ProjectMetricsNotifier, ProjectMetrics>((ref) {
      final prefs = ref
          .watch(sharedPreferencesProvider)
          .maybeWhen(data: (data) => data, orElse: () => null);
      return ProjectMetricsNotifier(ref, prefs);
    });
