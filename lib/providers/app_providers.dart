import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../models/file_system_item.dart';
import '../models/project_node.dart';
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

// Project loading service provider
class ProjectLoadingService {
  final Ref ref;

  ProjectLoadingService(this.ref);

  Future<bool> tryLoadProject(String directoryPath) async {
    try {
      // Validate that this is a Flutter project
      final dir = Directory(directoryPath);
      final pubspecFile = File('${dir.path}/pubspec.yaml');
      final libDir = Directory('${dir.path}/lib');

      if (!await pubspecFile.exists() || !await libDir.exists()) {
        return false;
      }

      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') &&
          !pubspecContent.contains('sdk: flutter')) {
        return false;
      }

      // Load the project
      ref.read(projectLoadedProvider.notifier).state = true;
      ref.read(currentProjectPathProvider.notifier).state = directoryPath;
      return true;
    } catch (e) {
      return false;
    }
  }

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

  Future<void> updateMruList(String directoryPath) async {
    final currentMruFolders = ref.read(mruFoldersProvider);

    // Only update if this is a new directory or needs reordering
    final currentIndex = currentMruFolders.indexOf(directoryPath);

    if (currentIndex == 0) {
      // Already at the front, no need to update
      return;
    }

    final updatedMruFolders = List<String>.from(currentMruFolders);

    if (currentIndex > 0) {
      // Move existing item to front
      updatedMruFolders.removeAt(currentIndex);
    }

    // Add to front (whether it was existing or new)
    updatedMruFolders.insert(0, directoryPath);

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
      // Silently handle SharedPreferences errors
    }
  }
}

// Project loading service provider
final projectLoadingServiceProvider = Provider<ProjectLoadingService>((ref) {
  return ProjectLoadingService(ref);
});
