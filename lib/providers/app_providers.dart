import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/file_system_item.dart';
import '../models/project_node.dart';
import '../models/document_state.dart';
import '../services/project_service.dart';
import '../utils/file_type_utils.dart';

// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

// State management for the selected file
final selectedFileProvider = StateProvider<FileSystemItem?>((ref) => null);

// State management for project loading
final projectLoadedProvider = StateProvider<bool>((ref) => false);

// State management for current project path
final currentProjectPathProvider = StateProvider<String?>((ref) => null);

// State management for current project root
final currentProjectRootProvider = StateProvider<ProjectNode?>((ref) => null);

// State management for project loading state
final projectLoadingProvider = StateProvider<bool>((ref) => false);

// State management for MRU folders
final mruFoldersProvider = StateProvider<List<String>>((ref) => []);

// MRU folders loader that loads from SharedPreferences
final mruFoldersLoaderProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  const mruFoldersKey = 'mru_folders';
  final mruList = prefs.getStringList(mruFoldersKey) ?? [];

  // Filter out folders that don't exist
  return mruList.where((path) => Directory(path).existsSync()).toList();
});

// Project management service - unified approach for all project operations
class ProjectManager {
  final Logger _logger = Logger('ProjectManager');

  final Ref ref;

  ProjectManager(this.ref);

  /// Load a project with proper cleanup and MRU management
  Future<bool> loadProject(String directoryPath) async {
    try {
      _logger.info('loadProject called with: $directoryPath');
      _logger.info('Loading project: $directoryPath');

      // Set loading state to true
      _logger.fine('Setting loading state to true');
      ref.read(projectLoadingProvider.notifier).state = true;

      // Check if there's already a project loaded
      final currentProjectLoaded = ref.read(projectLoadedProvider);
      _logger.fine('Current project loaded: $currentProjectLoaded');

      if (currentProjectLoaded) {
        _logger.info('Unloading current project first...');
        await unloadProject();
        _logger.info('Current project unloaded');
      }

      // Use ProjectService to load the new project
      final projectService = ref.read(projectServiceProvider);
      final success = await projectService.loadProject(directoryPath);

      if (success) {
        _logger.info('Project loaded successfully');

        // Update MRU list - move selected project to top
        await _updateMruList(directoryPath);
        _logger.info('MRU list updated');
      }

      // Set loading state to false
      _logger.fine('Setting loading state to false');
      ref.read(projectLoadingProvider.notifier).state = false;

      return success;
    } catch (e) {
      _logger.severe('Error loading project: $e');
      // Set loading state to false on error
      ref.read(projectLoadingProvider.notifier).state = false;
      return false;
    }
  }

  /// Unload the current project
  Future<void> unloadProject() async {
    try {
      _logger.info('Unloading project...');

      // Use ProjectService to unload
      final projectService = ref.read(projectServiceProvider);
      projectService.unloadProject();

      // Clear all project-related providers
      ref.read(projectLoadedProvider.notifier).state = false;
      ref.read(currentProjectPathProvider.notifier).state = null;
      ref.read(currentProjectRootProvider.notifier).state = null;
      ref.read(selectedFileProvider.notifier).state = null;

      // Clear all open documents and reset active document index
      ref.read(openDocumentsProvider.notifier).state = [];
      ref.read(activeDocumentIndexProvider.notifier).state = -1;

      _logger.info('Project unloaded successfully');
    } catch (e) {
      _logger.severe('Error unloading project: $e');
    }
  }

  /// Update MRU list with the selected project at the top
  Future<void> _updateMruList(String directoryPath) async {
    final currentMruFolders = ref.read(mruFoldersProvider);

    // Create updated MRU list
    final updatedMruFolders = List<String>.from(currentMruFolders);

    // Remove if exists (to avoid duplicates)
    updatedMruFolders.remove(directoryPath);

    // Add to front
    updatedMruFolders.insert(0, directoryPath);

    // Limit to 5 items
    if (updatedMruFolders.length > 5) {
      updatedMruFolders.removeRange(5, updatedMruFolders.length);
    }

    // Update the provider
    ref.read(mruFoldersProvider.notifier).state = updatedMruFolders;

    // Save to SharedPreferences
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setStringList('mru_folders', updatedMruFolders);
    } catch (e) {
      _logger.severe('Error saving MRU list: $e');
    }
  }

  /// Try to reopen the last opened file in the project
  Future<void> tryReopenLastFile(String projectPath) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final lastFilePath = prefs.getString('last_opened_file');

      if (lastFilePath == null || lastFilePath.isEmpty) {
        return;
      }

      // Check if the file exists
      final file = File(lastFilePath);
      if (!await file.exists()) {
        return;
      }

      // Check if the file is in the current project
      if (!p.isWithin(projectPath, lastFilePath)) {
        return;
      }

      // Check if it's a source file
      if (!FileTypeUtils.isFileSupportedInEditor(lastFilePath)) {
        return;
      }

      // Create FileSystemItem and set it as selected
      final fileSystemItem = FileSystemItem.fromFileSystemEntity(file);
      ref.read(selectedFileProvider.notifier).state = fileSystemItem;
    } catch (e) {
      // Silently handle errors
    }
  }
}

// Unified project manager provider
final projectManagerProvider = Provider<ProjectManager>((ref) {
  return ProjectManager(ref);
});

// Project service provider for complete project management
final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(ref);
});

// State management for open documents
final openDocumentsProvider = StateProvider<List<DocumentState>>((ref) => []);

// State management for active document index
final activeDocumentIndexProvider = StateProvider<int>((ref) => -1);

// Active document provider (computed from open documents and active index)
final activeDocumentProvider = Provider<DocumentState?>((ref) {
  final documents = ref.watch(openDocumentsProvider);
  final activeIndex = ref.watch(activeDocumentIndexProvider);
  if (activeIndex >= 0 && activeIndex < documents.length) {
    return documents[activeIndex];
  }
  return null;
});

// State management for project creation errors
final projectCreationErrorProvider = StateProvider<String?>((ref) => null);

// Loading action status
enum LoadingStatus { pending, success, failed }

// Loading action model
class LoadingAction {
  final int step;
  final String text;
  LoadingStatus status;

  LoadingAction(this.step, this.text, this.status);
}

// State management for loading actions log
final loadingActionsProvider = StateProvider<List<LoadingAction>>((ref) => []);

// State management for project metrics (cached in SharedPreferences)
class ProjectMetricsNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref ref;
  final SharedPreferences? prefs;

  ProjectMetricsNotifier(this.ref, this.prefs) : super({}) {
    _loadCachedMetrics();
  }

  void _loadCachedMetrics() {
    if (prefs == null) return;

    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath != null) {
      final key = 'project_metrics_$projectPath';
      final jsonString = prefs!.getString(key);
      if (jsonString != null) {
        try {
          final cached = jsonDecode(jsonString) as Map<String, dynamic>;
          state = cached;
        } catch (e) {
          // Ignore invalid cached data
        }
      }
    }
  }

  Future<void> updateMetrics(
    String projectPath,
    Map<String, dynamic> metrics,
  ) async {
    if (prefs == null) return;

    state = metrics;
    final key = 'project_metrics_$projectPath';
    final jsonString = jsonEncode(metrics);
    await prefs!.setString(key, jsonString);
  }

  void clearMetrics(String projectPath) {
    if (prefs == null) return;

    state = {};
    final key = 'project_metrics_$projectPath';
    prefs!.remove(key);
  }
}

final projectMetricsProvider =
    StateNotifierProvider<ProjectMetricsNotifier, Map<String, dynamic>>((ref) {
      final prefs = ref
          .watch(sharedPreferencesProvider)
          .maybeWhen(data: (data) => data, orElse: () => null);
      return ProjectMetricsNotifier(ref, prefs);
    });
