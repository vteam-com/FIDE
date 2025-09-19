import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
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

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Try to get saved theme mode from shared preferences
  // For now, default to system
  return ThemeMode.system;
});

// Project management service - unified approach for all project operations
class ProjectManager {
  final Ref ref;

  ProjectManager(this.ref);

  /// Load a project with proper cleanup and MRU management
  Future<bool> loadProject(String directoryPath) async {
    try {
      print('ProjectManager: Loading project: $directoryPath');

      // Check if there's already a project loaded
      final currentProjectLoaded = ref.read(projectLoadedProvider);
      print('ProjectManager: Current project loaded: $currentProjectLoaded');

      if (currentProjectLoaded) {
        print('ProjectManager: Unloading current project first...');
        await unloadProject();
        print('ProjectManager: Current project unloaded');
      }

      // Use ProjectService to load the new project
      final projectService = ref.read(projectServiceProvider);
      final success = await projectService.loadProject(directoryPath);

      if (success) {
        print('ProjectManager: Project loaded successfully');

        // Update MRU list - move selected project to top
        await _updateMruList(directoryPath);
        print('ProjectManager: MRU list updated');
      }

      return success;
    } catch (e) {
      print('ProjectManager: Error loading project: $e');
      return false;
    }
  }

  /// Unload the current project
  Future<void> unloadProject() async {
    try {
      print('ProjectManager: Unloading project...');

      // Use ProjectService to unload
      final projectService = ref.read(projectServiceProvider);
      projectService.unloadProject();

      // Clear all project-related providers
      ref.read(projectLoadedProvider.notifier).state = false;
      ref.read(currentProjectPathProvider.notifier).state = null;
      ref.read(currentProjectRootProvider.notifier).state = null;
      ref.read(selectedFileProvider.notifier).state = null;

      print('ProjectManager: Project unloaded successfully');
    } catch (e) {
      print('ProjectManager: Error unloading project: $e');
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
      print('ProjectManager: Error saving MRU list: $e');
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
      if (!path.isWithin(projectPath, lastFilePath)) {
        return;
      }

      // Check if it's a source file
      if (!FileTypeUtils.isSourceFile(lastFilePath)) {
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
