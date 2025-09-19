import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/file_system_watcher.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing project operations independently of UI
class ProjectService {
  final Ref _ref;
  final GitService _gitService = GitService();
  final FileSystemWatcher _fileSystemWatcher = FileSystemWatcher();

  ProjectNode? _currentProjectRoot;
  StreamSubscription? _watcherSubscription;

  ProjectService(this._ref);

  /// Get the current project root
  ProjectNode? get currentProjectRoot => _currentProjectRoot;

  /// Check if a directory is a valid Flutter project
  Future<bool> _isFlutterProject(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);

      // Check if pubspec.yaml exists (required for Flutter projects)
      final pubspecFile = File('${dir.path}/pubspec.yaml');
      if (!await pubspecFile.exists()) {
        return false;
      }

      // Check if lib directory exists (typical Flutter project structure)
      final libDir = Directory('${dir.path}/lib');
      if (!await libDir.exists()) {
        return false;
      }

      // Additional check: verify pubspec.yaml contains flutter dependency
      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') &&
          !pubspecContent.contains('sdk: flutter')) {
        return false;
      }

      return true;
    } catch (e) {
      // If we can't read the directory, it's not accessible anyway
      return false;
    }
  }

  /// Load a project completely independently of UI
  Future<bool> loadProject(String directoryPath) async {
    try {
      // Validate that this is a Flutter project
      if (!await _isFlutterProject(directoryPath)) {
        debugPrint('Not a valid Flutter project: $directoryPath');
        return false;
      }

      debugPrint('Loading project: $directoryPath');

      // Unload current project first to ensure clean state
      if (_currentProjectRoot != null) {
        debugPrint('Unloading previous project...');
        unloadProject();
      }

      // Create project root node
      final root = await ProjectNode.fromFileSystemEntity(
        Directory(directoryPath),
      );

      // Perform initial recursive enumeration
      debugPrint('Performing initial file enumeration...');
      final result = await root.enumerateContentsRecursive();

      if (result != LoadChildrenResult.success) {
        debugPrint('Failed to enumerate project contents: $result');
        return false;
      }

      // Store the project root
      _currentProjectRoot = root;

      // Load Git status for the project
      await _loadGitStatus();

      // Initialize file system watcher for incremental updates
      debugPrint('Setting up file system watcher...');
      _fileSystemWatcher.initialize(_currentProjectRoot!, () {
        // This callback will be called when file system changes occur
        // The UI will be updated through the provider state changes
        debugPrint('File system change detected, updating UI...');
        _notifyProjectUpdated();
      });

      // Update providers - ensure proper order
      debugPrint('Updating providers...');
      debugPrint('Setting currentProjectPathProvider to: $directoryPath');
      _ref.read(currentProjectPathProvider.notifier).state = directoryPath;
      debugPrint(
        'Setting currentProjectRootProvider to: ${_currentProjectRoot?.path}',
      );
      _ref.read(currentProjectRootProvider.notifier).state =
          _currentProjectRoot;
      debugPrint('Setting projectLoadedProvider to: true');
      _ref.read(projectLoadedProvider.notifier).state = true;

      debugPrint('Project loaded successfully: $directoryPath');
      debugPrint(
        'Total files enumerated: ${_countFiles(_currentProjectRoot!)}',
      );

      return true;
    } catch (e) {
      debugPrint('Error loading project: $e');
      return false;
    }
  }

  /// Unload the current project
  void unloadProject() {
    debugPrint('Unloading project...');

    // Clean up file system watcher
    _fileSystemWatcher.dispose();

    // Clear project state
    _currentProjectRoot = null;

    // Update providers
    _ref.read(projectLoadedProvider.notifier).state = false;
    _ref.read(currentProjectPathProvider.notifier).state = null;
    _ref.read(currentProjectRootProvider.notifier).state = null;
    _ref.read(selectedFileProvider.notifier).state = null;

    debugPrint('Project unloaded');
  }

  /// Load Git status for the current project
  Future<void> _loadGitStatus() async {
    if (_currentProjectRoot == null) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(
        _currentProjectRoot!.path,
      );
      if (!isGitRepo) {
        debugPrint('Not a Git repository: ${_currentProjectRoot!.path}');
        return;
      }

      // Get Git status
      final gitStatus = await _gitService.getStatus(_currentProjectRoot!.path);
      debugPrint(
        'Git status loaded: ${gitStatus.staged.length} staged, ${gitStatus.unstaged.length} unstaged, ${gitStatus.untracked.length} untracked',
      );

      // Update all nodes with Git status recursively
      _updateNodeGitStatus(_currentProjectRoot!, gitStatus);
    } catch (e) {
      // Silently handle Git status errors
      debugPrint('Error loading Git status: $e');
    }
  }

  /// Update Git status for all nodes recursively
  void _updateNodeGitStatus(ProjectNode node, GitStatus gitStatus) {
    if (node.isFile) {
      final relativePath = path.relative(
        node.path,
        from: _currentProjectRoot!.path,
      );

      if (gitStatus.staged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.added;
      } else if (gitStatus.unstaged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.modified;
      } else if (gitStatus.untracked.contains(relativePath)) {
        node.gitStatus = GitFileStatus.untracked;
      } else {
        node.gitStatus = GitFileStatus.clean;
      }
    }

    // Recursively update children
    for (final child in node.children) {
      _updateNodeGitStatus(child, gitStatus);
    }
  }

  /// Notify that the project has been updated (for UI refresh)
  void _notifyProjectUpdated() {
    // Force a refresh of the current project root provider
    if (_currentProjectRoot != null) {
      _ref.read(currentProjectRootProvider.notifier).state =
          _currentProjectRoot;
    }
  }

  /// Count total files in the project (for debugging)
  int _countFiles(ProjectNode node) {
    int count = node.isFile ? 1 : 0;
    for (final child in node.children) {
      count += _countFiles(child);
    }
    return count;
  }

  /// Get project statistics
  Map<String, int> getProjectStats() {
    if (_currentProjectRoot == null) return {};

    int fileCount = 0;
    int directoryCount = 0;

    void countNodes(ProjectNode node) {
      if (node.isFile) {
        fileCount++;
      } else if (node.isDirectory) {
        directoryCount++;
      }

      for (final child in node.children) {
        countNodes(child);
      }
    }

    countNodes(_currentProjectRoot!);

    return {
      'files': fileCount,
      'directories': directoryCount,
      'total': fileCount + directoryCount,
    };
  }

  /// Dispose of the service
  void dispose() {
    _fileSystemWatcher.dispose();
    _watcherSubscription?.cancel();
    _currentProjectRoot = null;
  }
}
