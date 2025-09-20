import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';

/// Service for monitoring file system changes and applying incremental updates
class FileSystemWatcher {
  static final FileSystemWatcher _instance = FileSystemWatcher._internal();
  factory FileSystemWatcher() => _instance;
  FileSystemWatcher._internal();

  static final Logger _logger = Logger('FileSystemWatcher');

  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  final Map<String, ProjectNode> _watchedDirectories = {};

  Function? _onTreeUpdated;

  /// Initialize the watcher with the root project node
  void initialize(ProjectNode rootNode, Function onTreeUpdated) {
    _onTreeUpdated = onTreeUpdated;

    // Start watching the root directory and all subdirectories
    _watchDirectoryRecursive(rootNode);
  }

  /// Stop all watchers and clean up
  void dispose() {
    for (final subscription in _watchers.values) {
      subscription.cancel();
    }
    _watchers.clear();
    _watchedDirectories.clear();
    _onTreeUpdated = null;
  }

  /// Watch a directory and all its subdirectories recursively
  void _watchDirectoryRecursive(ProjectNode node) {
    if (!node.isDirectory) return;

    // Watch this directory
    _watchDirectory(node);

    // Watch all subdirectories recursively
    for (final child in node.children) {
      if (child.isDirectory) {
        _watchDirectoryRecursive(child);
      }
    }
  }

  /// Watch a single directory
  void _watchDirectory(ProjectNode node) {
    if (!node.isDirectory || _watchers.containsKey(node.path)) return;

    try {
      final directory = Directory(node.path);
      final subscription = directory.watch().listen(
        (event) => _handleFileSystemEvent(event, node),
        onError: (error) => _handleWatchError(error, node.path),
      );

      _watchers[node.path] = subscription;
      _watchedDirectories[node.path] = node;
    } catch (e) {
      _logger.severe('Failed to watch directory ${node.path}: $e');
    }
  }

  /// Handle file system events
  void _handleFileSystemEvent(FileSystemEvent event, ProjectNode parentNode) {
    final eventPath = event.path;
    final eventType = event.type;

    try {
      switch (eventType) {
        case FileSystemEvent.create:
          _handleFileCreated(eventPath, parentNode);
          break;
        case FileSystemEvent.delete:
          _handleFileDeleted(eventPath, parentNode);
          break;
        case FileSystemEvent.modify:
          _handleFileModified(eventPath, parentNode);
          break;
        case FileSystemEvent.move:
          // Handle move events (both from and to paths)
          final moveEvent = event as FileSystemMoveEvent;
          if (moveEvent.destination != null) {
            _handleFileMoved(eventPath, moveEvent.destination!, parentNode);
          }
          break;
      }

      // Notify listeners that the tree has been updated
      _onTreeUpdated?.call();
    } catch (e) {
      _logger.severe('Error handling file system event: $e');
    }
  }

  /// Handle file creation
  void _handleFileCreated(String filePath, ProjectNode parentNode) async {
    try {
      final entity = FileSystemEntity.typeSync(filePath);
      final isDirectory = entity == FileSystemEntityType.directory;

      // Create new ProjectNode
      final newNode = await ProjectNode.fromFileSystemEntity(
        isDirectory ? Directory(filePath) : File(filePath),
      );

      // Add to parent node
      parentNode.addChild(newNode);

      // If it's a directory, start watching it
      if (isDirectory) {
        _watchDirectory(newNode);
      }
    } catch (e) {
      _logger.severe('Error handling file creation: $e');
    }
  }

  /// Handle file deletion
  void _handleFileDeleted(String filePath, ProjectNode parentNode) {
    // Remove from parent node
    final removed = parentNode.removeChild(filePath);

    // If it was a directory, stop watching it and all its subdirectories
    if (removed && _watchers.containsKey(filePath)) {
      _stopWatchingDirectory(filePath);
    }

    if (removed) {
      _logger.info('Removed: $filePath');
    }
  }

  /// Handle file modification
  void _handleFileModified(String filePath, ProjectNode parentNode) async {
    try {
      // For modifications, we might want to update metadata
      // For now, just mark as modified (could be extended for more detailed tracking)
      final existingNode = parentNode.children.cast<ProjectNode?>().firstWhere(
        (child) => child?.path == filePath,
        orElse: () => null,
      );

      if (existingNode != null) {
        // Could update modification time or other metadata here
        _logger.info('Modified: $filePath');
      }
    } catch (e) {
      _logger.severe('Error handling file modification: $e');
    }
  }

  /// Handle file move/rename
  void _handleFileMoved(
    String fromPath,
    String toPath,
    ProjectNode parentNode,
  ) {
    // Remove the old node
    parentNode.removeChild(fromPath);

    // If it was a directory being watched, update the watcher
    if (_watchers.containsKey(fromPath)) {
      final subscription = _watchers.remove(fromPath);
      subscription?.cancel();

      _watchedDirectories.remove(fromPath);
    }

    // Add the new node (this will trigger the create handler)
    _handleFileCreated(toPath, parentNode);

    _logger.info('Moved: $fromPath -> $toPath');
  }

  /// Stop watching a directory and all its subdirectories
  void _stopWatchingDirectory(String directoryPath) {
    // Cancel this directory's watcher
    final subscription = _watchers.remove(directoryPath);
    subscription?.cancel();

    _watchedDirectories.remove(directoryPath);

    // Cancel watchers for all subdirectories
    final subDirsToRemove = _watchers.keys
        .where((watchedPath) => path.isWithin(directoryPath, watchedPath))
        .toList();

    for (final subDir in subDirsToRemove) {
      final subSubscription = _watchers.remove(subDir);
      subSubscription?.cancel();
      _watchedDirectories.remove(subDir);
    }
  }

  /// Handle watcher errors
  void _handleWatchError(Object error, String directoryPath) {
    _logger.severe('Watcher error for $directoryPath: $error');

    // Remove the failed watcher
    final subscription = _watchers.remove(directoryPath);
    subscription?.cancel();
    _watchedDirectories.remove(directoryPath);
  }

  /// Add a new directory to watch (when a new directory is created)
  void addDirectoryToWatch(ProjectNode directoryNode) {
    if (directoryNode.isDirectory) {
      _watchDirectoryRecursive(directoryNode);
    }
  }

  /// Remove a directory from watch (when a directory is deleted)
  void removeDirectoryFromWatch(String directoryPath) {
    _stopWatchingDirectory(directoryPath);
  }
}
