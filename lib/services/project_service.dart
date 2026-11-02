import 'dart:async';
import 'dart:io';

import 'package:fide/models/project_node.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/file_system_watcher.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/loading_progress.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_state_sink.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Opens a project's file tree, watches it and decorates it with Git
/// status, publishing it through a [ProjectStateSink].
///
/// `ProjectManager` owns the project lifecycle: it unloads the previous
/// project (closing its documents) before [loadProject] and remembers the
/// opened one.
class ProjectService {
  final Logger _logger = Logger('ProjectService');

  final ProjectStateSink _stateSink;
  final GitService _gitService;
  final FileSystemWatcher _fileSystemWatcher;
  final ProjectTreeLoader _loadTree;
  final ProjectConfigReader _config;

  ProjectNode? _currentProjectRoot;

  /// Creates a service publishing through [_stateSink], reading Git status
  /// with [_gitService], watching with [_fileSystemWatcher], reading the
  /// tree with [_loadTree] and the pubspec with [_config].
  ProjectService(
    this._stateSink,
    this._gitService,
    this._fileSystemWatcher,
    this._config, {
    required this._loadTree,
  });

  /// Get the current project root
  ProjectNode? get currentProjectRoot => _currentProjectRoot;

  /// Check if a directory is a valid Flutter project
  Future<bool> _isFlutterProject(String directoryPath) async {
    try {
      final paths = ProjectPaths(directoryPath);
      if (!await Directory(paths.libDir).exists()) return false;
      return (await _config.pubspec(directoryPath))?.isFlutter ?? false;
    } catch (_) {
      // If we can't read the directory, it's not accessible anyway
      return false;
    }
  }

  /// Opens the Flutter project at [directoryPath], reporting each step to
  /// [progress]: validates it, reads its tree, watches it and publishes
  /// it; Git status follows in the background. Returns whether it opened.
  Future<bool> loadProject(
    String directoryPath,
    LoadingProgress progress,
  ) async {
    _logger.info('Loading project: $directoryPath');
    try {
      final opened =
          await progress.step(
            'Validating Flutter project',
            () => _isFlutterProject(directoryPath),
          ) &&
          await progress.step('Loading project structure', () async {
            _currentProjectRoot = await _loadTree(directoryPath);
            return true;
          }) &&
          await progress.step('Setting up file system watcher', _watch) &&
          await progress.step('Updating application state', () {
            _publish(directoryPath);
            return true;
          });
      if (!opened) {
        _logger.warning('Not a valid Flutter project: $directoryPath');
        return false;
      }
    } catch (e) {
      _logger.severe('Error loading project: $e');
      return false;
    }

    // Git status decorates the tree once the IDE is open, so a slow or
    // large repository never holds up the loading screen
    unawaited(_refreshGitStatus());
    _logger.info(
      'Project loaded: $directoryPath, '
      '${_countFiles(_currentProjectRoot!)} files',
    );
    return true;
  }

  /// Watches the current tree for incremental updates.
  bool _watch() {
    _fileSystemWatcher.initialize(_currentProjectRoot!, _notifyProjectUpdated);
    return true;
  }

  /// Publishes the project at [directoryPath] and its current tree.
  void _publish(String directoryPath) {
    _stateSink.setCurrentProjectPath(directoryPath);
    _stateSink.setCurrentProjectRoot(_currentProjectRoot);
    _stateSink.setProjectLoaded(true);
  }

  /// Stops watching the current project and clears it from the state.
  void unloadProject() {
    _logger.info('Unloading project...');
    _fileSystemWatcher.dispose();
    _currentProjectRoot = null;
    _stateSink.setProjectLoaded(false);
    _stateSink.setCurrentProjectPath(null);
    _stateSink.setCurrentProjectRoot(null);
    _stateSink.clearSelectedFile();
  }

  /// Tags the current tree with Git status in the background, then refreshes
  /// the UI; skipped when another project was loaded in the meantime.
  Future<void> _refreshGitStatus() async {
    final root = _currentProjectRoot;
    if (root == null) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(root.path);
      if (!isGitRepo) {
        _logger.info('Not a Git repository: ${root.path}');
        return;
      }

      // Get Git status
      final gitStatus = await _gitService.getStatus(root.path);
      if (!identical(root, _currentProjectRoot)) return;
      _logger.info(
        'Git status loaded: ${gitStatus.staged.length} staged, ${gitStatus.unstaged.length} unstaged, ${gitStatus.untracked.length} untracked',
      );

      // Update all nodes with Git status recursively
      _updateNodeGitStatus(root, gitStatus);
      _notifyProjectUpdated();
    } catch (e) {
      // Silently handle Git status errors
      _logger.severe('Error loading Git status: $e');
    }
  }

  /// Update Git status for all nodes recursively
  void _updateNodeGitStatus(ProjectNode node, GitStatus gitStatus) {
    if (node.isFile) {
      final relativePath = p.relative(
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

  /// Bumps the tree revision so tree views rebuild over the same root;
  /// nothing once the project is unloaded or the service [dispose]d.
  void _notifyProjectUpdated() {
    if (_currentProjectRoot != null) _stateSink.bumpProjectTreeRevision();
  }

  /// Count total files in the project (for debugging)
  int _countFiles(ProjectNode node) {
    int count = node.isFile ? 1 : 0;
    for (final child in node.children) {
      count += _countFiles(child);
    }
    return count;
  }

  /// Stops watching, so no update reaches the sink after its provider is
  /// gone, and forgets the project.
  void dispose() {
    _fileSystemWatcher.dispose();
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
