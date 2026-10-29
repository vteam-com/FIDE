import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/providers/project_service.dart';
import 'package:fide/providers/project_state_sink.dart';
import 'package:fide/providers/service_providers.dart';
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

// State management for current project root
final currentProjectRootProvider = StateProvider<ProjectNode?>((_) => null);

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
