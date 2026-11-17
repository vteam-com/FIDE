// ignore: fcheck_dead_code
import 'dart:async';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Service for monitoring file system changes and applying incremental updates
class FileSystemWatcher {
  static final Logger _logger = Logger('FileSystemWatcher');

  /// Whether [initialize] subscribes to file system events; tests that
  /// can't run real watchers and timers pass false.
  final bool watchEnabled;

  final ProjectTreeReader _reader;

  /// Creates a watcher that reads new entries with [reader]; see
  /// [watchEnabled].
  FileSystemWatcher({this.watchEnabled = true, ProjectTreeReader? reader})
    : _reader = reader ?? const ProjectTreeReader();

  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  final Map<String, ProjectNode> _watchedDirectories = {};

  void Function()? _onTreeUpdated;

  /// Bumped by [dispose], so changes read for a previous project are
  /// dropped.
  int _session = 0;

  /// The events being applied, one after another.
  Future<void> _events = Future.value();

  // Debouncing for UI updates
  Timer? _updateDebounceTimer;

  /// Watches [rootNode]'s loaded folders, calling [onTreeUpdated] after
  /// each burst of changes applied to the tree.
  void initialize(ProjectNode rootNode, void Function() onTreeUpdated) {
    _onTreeUpdated = onTreeUpdated;

    if (watchEnabled) {
      // Start watching the root directory and all subdirectories
      _watchDirectoryRecursive(rootNode);
    } else {
      _logger.info('FileSystemWatcher: watching disabled');
    }
  }

  /// Stop all watchers and clean up
  void dispose() {
    for (final subscription in _watchers.values) {
      subscription.cancel();
    }
    _watchers.clear();
    _watchedDirectories.clear();
    _session++;
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = null;
    _onTreeUpdated = null;
  }

  /// Paths of the folders watched now.
  Iterable<String> get watchedPaths => _watchers.keys;

  /// Watches [node] and its loaded subdirectories; folders left unread
  /// (such as build output) are not watched, so their churn costs nothing
  /// and no event fills them in partially before they are expanded.
  void _watchDirectoryRecursive(ProjectNode node) {
    if (!node.isDirectory || !node.isLoaded) return;

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

  /// Queues [event], from [parentNode]'s watcher, behind the events before
  /// it, so a file created then deleted at once ends up removed; schedules
  /// a tree update when it changed the tree.
  void _handleFileSystemEvent(FileSystemEvent event, ProjectNode parentNode) {
    final session = _session;
    _events = _events.then((_) async {
      if (await _applyEvent(event, parentNode, session)) _scheduleTreeUpdate();
    });
  }

  /// Applies [event] to [parentNode], the watched folder it happened in;
  /// true when the tree changed. A modified file leaves the tree as it is,
  /// and so do events about the folder itself, which macOS reports for a
  /// folder created moments before it is watched.
  Future<bool> _applyEvent(
    FileSystemEvent event,
    ProjectNode parentNode,
    int session,
  ) async {
    if (p.dirname(event.path) != parentNode.path) return false;
    try {
      switch (event.type) {
        case FileSystemEvent.create:
          return await _handleFileCreated(
            event.path,
            event.isDirectory,
            parentNode,
            session,
          );
        case FileSystemEvent.delete:
          return _handleFileDeleted(event.path, parentNode);
        case FileSystemEvent.move:
          final destination = (event as FileSystemMoveEvent).destination;
          if (destination == null) return false;
          return await _handleFileMoved(
            event.path,
            destination,
            event.isDirectory,
            parentNode,
            session,
          );
      }
    } catch (e) {
      _logger.severe('Error handling file system event: $e');
    }
    return false;
  }

  /// Schedule a debounced tree update to prevent UI spamming
  void _scheduleTreeUpdate() {
    if (_onTreeUpdated == null) return;
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(AppDuration.updateDebounce, () {
      _onTreeUpdated?.call();
      _updateDebounceTimer = null;
    });
  }

  /// Adds the entry created at [filePath] to [parentNode], replacing the
  /// file listed there; true when the tree changed.
  ///
  /// A new folder is read and watched like the folders loaded with the
  /// tree, unless [ProjectFiles] skips it: tool output such as `build/` or
  /// `.dart_tool/` is listed but left unread and unwatched, so a build's
  /// thousands of files cost nothing. Nothing is added when [parentNode]
  /// isn't loaded, or when the watcher was disposed since the event
  /// ([session] changed).
  Future<bool> _handleFileCreated(
    String filePath,
    bool isDirectory,
    ProjectNode parentNode,
    int session,
  ) async {
    if (!parentNode.isLoaded) return false;
    final existing = _childAt(parentNode, filePath);
    // A folder already listed keeps its loaded subtree and watchers
    if (isDirectory && existing != null && existing.isDirectory) return false;
    try {
      final newNode = await _reader.nodeFor(
        isDirectory ? Directory(filePath) : File(filePath),
      );
      final watched = isDirectory && !ProjectFiles.isSkipped(newNode.name);
      if (watched) await _reader.loadTree(newNode);
      if (session != _session) return false;

      if (existing != null && existing.isDirectory) {
        _stopWatchingDirectory(filePath);
      }
      parentNode.addChild(newNode);
      if (watched) _watchDirectoryRecursive(newNode);
      // A file written over one already listed leaves the tree as it is
      return existing == null || existing.isDirectory;
    } catch (e) {
      _logger.severe('Error handling file creation: $e');
      return false;
    }
  }

  /// [parentNode]'s child at [childPath], or null.
  static ProjectNode? _childAt(ProjectNode parentNode, String childPath) {
    for (final child in parentNode.children) {
      if (child.path == childPath) return child;
    }
    return null;
  }

  /// Removes the entry deleted at [filePath] from [parentNode], and its
  /// watchers; true when the tree changed.
  bool _handleFileDeleted(String filePath, ProjectNode parentNode) {
    final removed = parentNode.removeChild(filePath);
    if (removed) {
      _stopWatchingDirectory(filePath);
      _logger.info('Removed: $filePath');
    }
    return removed;
  }

  /// Moves the entry at [fromPath] in [parentNode] to [toPath], added to
  /// its watched folder; true when the tree changed. [isDirectory] and
  /// [session] are as for [_handleFileCreated].
  Future<bool> _handleFileMoved(
    String fromPath,
    String toPath,
    bool isDirectory,
    ProjectNode parentNode,
    int session,
  ) async {
    final removed = _handleFileDeleted(fromPath, parentNode);
    final toFolder = p.dirname(toPath);
    final toParent = toFolder == p.dirname(fromPath)
        ? parentNode
        : _watchedDirectories[toFolder];
    final added =
        toParent != null &&
        await _handleFileCreated(toPath, isDirectory, toParent, session);
    _logger.info('Moved: $fromPath -> $toPath');
    return removed || added;
  }

  /// Stop watching a directory and all its subdirectories
  void _stopWatchingDirectory(String directoryPath) {
    // Cancel this directory's watcher
    final subscription = _watchers.remove(directoryPath);
    subscription?.cancel();

    _watchedDirectories.remove(directoryPath);

    // Cancel watchers for all subdirectories
    final subDirsToRemove = _watchers.keys
        .where((watchedPath) => p.isWithin(directoryPath, watchedPath))
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
