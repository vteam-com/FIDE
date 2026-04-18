import 'dart:convert';
import 'dart:io';

import 'package:fide/models/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/project_service.dart';
import 'package:fide/services/project_state_sink.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

export 'package:fide/models/loading_action.dart';

part 'project_manager.dart';
part 'project_metrics_notifier.dart';
part 'provider_project_state_sink.dart';

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

// State management for project loading state
final projectLoadingProvider = StateProvider<bool>((_) => false);

// State management for MRU folders
final mruFoldersProvider = StateProvider<List<String>>((_) => []);

// MRU folders loader that loads from SharedPreferences
final mruFoldersLoaderProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  const mruFoldersKey = 'mru_folders';
  final mruList = prefs.getStringList(mruFoldersKey) ?? [];

  // Filter out folders that don't exist
  return mruList.where((path) => Directory(path).existsSync()).toList();
});

// Unified project manager provider
final projectManagerProvider = Provider<ProjectManager>((ref) {
  return ProjectManager(ref);
});

// Project service provider for complete project management
final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(_ProviderProjectStateSink(ref));
});

// State management for project creation errors
final projectCreationErrorProvider = StateProvider<String?>(
  (_ /*ref*/) => null,
);

// State management for loading actions log
final loadingActionsProvider = StateProvider<List<LoadingAction>>(
  (_ /*ref*/) => [],
);

// State management for open documents
final openDocumentsProvider = StateProvider<List<DocumentState>>(
  (_ /*ref*/) => [],
);

// State management for active document index
final activeDocumentIndexProvider = StateProvider<int>((_ /*ref*/) => -1);

// Active document provider (computed from open documents and active index)
final activeDocumentProvider = Provider<DocumentState?>((ref) {
  final documents = ref.watch(openDocumentsProvider);
  final activeIndex = ref.watch(activeDocumentIndexProvider);
  if (activeIndex >= 0 && activeIndex < documents.length) {
    return documents[activeIndex];
  }
  return null;
});

final projectMetricsProvider =
    StateNotifierProvider<ProjectMetricsNotifier, Map<String, dynamic>>((ref) {
      final prefs = ref
          .watch(sharedPreferencesProvider)
          .maybeWhen(data: (data) => data, orElse: () => null);
      return ProjectMetricsNotifier(ref, prefs);
    });
