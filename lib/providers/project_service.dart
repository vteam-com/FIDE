import 'dart:async';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/providers/file_system_watcher.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/project_state_sink.dart';
import 'package:fide/providers/project_tree_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// Service for managing project operations independently of UI
class ProjectService {
  final Logger _logger = Logger('ProjectService');

  final ProjectStateSink _stateSink;
  final GitService _gitService;
  final FileSystemWatcher _fileSystemWatcher;
  final ProjectTreeLoader _loadTree;

  ProjectNode? _currentProjectRoot;
  StreamSubscription? _watcherSubscription;

  ProjectService(
    this._stateSink,
    this._gitService,
    this._fileSystemWatcher, {
    this._loadTree = loadProjectTreeInIsolate,
  });

  /// Get the current project root
  ProjectNode? get currentProjectRoot => _currentProjectRoot;

  /// Check if a directory is a valid Flutter project
  Future<bool> _isFlutterProject(String directoryPath) async {
    try {
      final paths = ProjectPaths(directoryPath);
      if (!await Directory(paths.libDir).exists()) return false;
      return (await Pubspec.read(paths.pubspec))?.isFlutter ?? false;
    } catch (_) {
      // If we can't read the directory, it's not accessible anyway
      return false;
    }
  }

  /// Load a project completely independently of UI
  Future<bool> loadProject(String directoryPath) async {
    final Duration duration = AppDuration.projectLoadDelay;

    try {
      // Clear loading actions
      _stateSink.replaceLoadingActions(const []);
      int step = 1;

      // Validate that this is a Flutter project
      _addLoadingAction(step++, 'Validating Flutter project');
      if (!await _isFlutterProject(directoryPath)) {
        _logger.warning('Not a valid Flutter project: $directoryPath');
        _updateLoadingActionStatus(step - 1, LoadingStatus.failed);
        return false;
      }
      _updateLoadingActionStatus(step - 1, LoadingStatus.success);
      await Future.delayed(duration);

      _logger.info('Loading project: $directoryPath');

      // Unload current project first to ensure clean state
      if (_currentProjectRoot != null) {
        _addLoadingAction(step++, 'Unloading previous project');
        _logger.info('Unloading previous project...');
        unloadProject();
        _updateLoadingActionStatus(step - 1, LoadingStatus.success);
        await Future.delayed(duration);
      }

      // Create project root node and perform enumeration in isolate
      _addLoadingAction(step++, 'Loading project structure');

      _currentProjectRoot = await _loadTree(directoryPath);

      if (_currentProjectRoot == null) {
        _logger.severe('Failed to load project structure');
        _updateLoadingActionStatus(step - 1, LoadingStatus.failed);
        return false;
      }
      _updateLoadingActionStatus(step - 1, LoadingStatus.success);
      await Future.delayed(duration);

      // Load Git status for the project
      _addLoadingAction(step++, 'Loading Git status');
      await _loadGitStatus();
      _updateLoadingActionStatus(step - 1, LoadingStatus.success);
      await Future.delayed(duration);

      // Initialize file system watcher for incremental updates
      _addLoadingAction(step++, 'Setting up file system watcher');
      _logger.info('Setting up file system watcher...');

      _fileSystemWatcher.initialize(_currentProjectRoot!, () {
        // This callback will be called when file system changes occur
        // The UI will be updated through the provider state changes
        _logger.info('File system change detected, updating UI...');
        _notifyProjectUpdated();
      });

      _updateLoadingActionStatus(step - 1, LoadingStatus.success);
      await Future.delayed(duration);

      // Update providers - ensure proper order
      _addLoadingAction(step++, 'Updating application state');
      _logger.info('Updating providers...');
      _logger.fine('Setting currentProjectPathProvider to: $directoryPath');
      _stateSink.setCurrentProjectPath(directoryPath);
      _logger.fine(
        'Setting currentProjectRootProvider to: ${_currentProjectRoot?.path}',
      );
      _stateSink.setCurrentProjectRoot(_currentProjectRoot);
      _logger.fine('Setting projectLoadedProvider to: true');
      _stateSink.setProjectLoaded(true);
      _updateLoadingActionStatus(step - 1, LoadingStatus.success);
      await Future.delayed(duration);
      await Future.delayed(duration);
      await Future.delayed(duration);

      _logger.info('Project loaded successfully: $directoryPath');
      _logger.info(
        'Total files enumerated: ${_countFiles(_currentProjectRoot!)}',
      );

      return true;
    } catch (e) {
      _logger.severe('Error loading project: $e');
      // Mark the last action as failed if any
      final actions = _stateSink.loadingActions;
      if (actions.isNotEmpty) {
        _updateLoadingActionStatus(actions.last.step, LoadingStatus.failed);
        await Future.delayed(duration);
      }
      return false;
    }
  }

  /// Unload the current project
  void unloadProject() {
    _logger.info('Unloading project...');

    // Clean up file system watcher
    _fileSystemWatcher.dispose();

    // Clear project state
    _currentProjectRoot = null;

    // Update providers
    _stateSink.setProjectLoaded(false);
    _stateSink.setCurrentProjectPath(null);
    _stateSink.setCurrentProjectRoot(null);
    _stateSink.clearSelectedFile();

    _logger.info('Project unloaded');
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
        _logger.info('Not a Git repository: ${_currentProjectRoot!.path}');
        return;
      }

      // Get Git status
      final gitStatus = await _gitService.getStatus(_currentProjectRoot!.path);
      _logger.info(
        'Git status loaded: ${gitStatus.staged.length} staged, ${gitStatus.unstaged.length} unstaged, ${gitStatus.untracked.length} untracked',
      );

      // Update all nodes with Git status recursively
      _updateNodeGitStatus(_currentProjectRoot!, gitStatus);
    } catch (e) {
      // Silently handle Git status errors
      _logger.severe('Error loading Git status: $e');
    }
  }

  /// Update Git status for all nodes recursively
  void _updateNodeGitStatus(ProjectNode node, GitStatus gitStatus) {
    if (node.isFile) {
      final relativePath = path.relative(
        node.path,
        from: _currentProjectRoot!.path,
      );

      node.gitStatus = gitStatus.statusOf(relativePath);
    }

    // Recursively update children
    for (final child in node.children) {
      _updateNodeGitStatus(child, gitStatus);
    }
  }

  /// Notify that the project has been updated (for UI refresh)
  void _notifyProjectUpdated() {
    // Force a refresh of the current project root provider
    // Check if container is still available (not disposed in tests)
    try {
      if (_currentProjectRoot != null) {
        _stateSink.setCurrentProjectRoot(_currentProjectRoot);
      }
    } catch (_) {
      // Container might be disposed in test environments, ignore
      _logger.fine(
        'Container disposed, skipping UI update in _notifyProjectUpdated',
      );
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

  /// Add a loading action to the log
  void _addLoadingAction(int step, String text) {
    final currentActions = _stateSink.loadingActions;
    final updatedActions = List<LoadingAction>.from(currentActions)
      ..add(LoadingAction(step, text, LoadingStatus.pending));
    _stateSink.replaceLoadingActions(updatedActions);
  }

  /// Update the status of a loading action
  void _updateLoadingActionStatus(int step, LoadingStatus status) {
    final currentActions = _stateSink.loadingActions;
    final updatedActions = currentActions.map((action) {
      if (action.step == step) {
        return LoadingAction(action.step, action.text, status);
      }
      return action;
    }).toList();
    _stateSink.replaceLoadingActions(updatedActions);
  }

  /// Dispose of the service
  void dispose() {
    _fileSystemWatcher.dispose();
    _watcherSubscription?.cancel();
    _currentProjectRoot = null;
  }
}

/// Isolate function for heavy file enumeration (runs off main thread)
/// Loads a project's full file tree from its root directory path.
typedef ProjectTreeLoader = Future<ProjectNode> Function(String directoryPath);

/// Default [ProjectTreeLoader]: enumerates the tree in a background isolate
/// so large projects don't block the UI.
Future<ProjectNode> loadProjectTreeInIsolate(String directoryPath) {
  return compute(_enumerateProjectStructureInIsolate, directoryPath);
}

/// [ProjectTreeLoader] that enumerates on the calling isolate, for tests
/// where spawning isolates is unavailable or unreliable.
Future<ProjectNode> loadProjectTreeInline(String directoryPath) async {
  return _enumerateProjectStructureInIsolate(directoryPath);
}

ProjectNode _enumerateProjectStructureInIsolate(String directoryPath) {
  const reader = ProjectTreeReader();
  final root = reader.nodeForSync(Directory(directoryPath));
  reader.loadTreeSync(root);
  return root;
}
