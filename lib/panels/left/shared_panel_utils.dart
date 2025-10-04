// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/utils/message_box.dart';

/// Shared state management for panel widgets
class PanelStateManager {
  final Logger _logger = Logger('PanelStateManager');
  final Map<String, bool> _expandedState = {};
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';
  ProjectNode? projectRoot;
  final GitService _gitService = GitService();
  final Set<String> _loadingDirectories = {};

  // Getters
  Map<String, bool> get expandedState => _expandedState;
  TextEditingController get filterController => _filterController;
  String get filterQuery => _filterQuery;
  Set<String> get loadingDirectories => _loadingDirectories;

  void initialize() {
    _filterController.addListener(_onFilterChanged);
  }

  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
  }

  void _onFilterChanged() {
    _filterQuery = _filterController.text.toLowerCase();
    // Clear expansion state when filter changes
    _expandedState.clear();
    // Expand directories that contain matching files when filtering
    if (_filterQuery.isNotEmpty && projectRoot != null) {
      _expandDirectoriesWithMatchingFiles(projectRoot!);
    }
  }

  void _expandDirectoriesWithMatchingFiles(ProjectNode node) {
    if (node.isDirectory) {
      bool hasMatchingDescendant = false;

      // Check if this directory or any descendant matches the filter
      if (_matchesFilter(node)) {
        hasMatchingDescendant = true;
      } else {
        // Check descendants recursively
        for (final child in node.children) {
          if (_hasMatchingDescendant(child)) {
            hasMatchingDescendant = true;
            break;
          }
        }
      }

      // If this directory has matching descendants, expand it
      if (hasMatchingDescendant) {
        _expandedState[node.path] = true;
        // Recursively expand all children that have matches
        for (final child in node.children) {
          if (child.isDirectory) {
            _expandDirectoriesWithMatchingFiles(child);
          }
        }
      }
    }
  }

  bool _hasMatchingDescendant(ProjectNode node) {
    // Check if this node matches
    if (_matchesFilter(node)) return true;

    // Check children recursively
    for (final child in node.children) {
      if (_hasMatchingDescendant(child)) return true;
    }

    return false;
  }

  bool _matchesFilter(ProjectNode node) {
    if (_filterQuery.isEmpty) return true;
    return node.name.toLowerCase().contains(_filterQuery);
  }

  bool matchesFilter(ProjectNode node) => _matchesFilter(node);

  Future<void> ensureDirectoryLoaded(ProjectNode node) async {
    if (node.children.isEmpty && node.isDirectory) {
      // Mark this directory as loading
      _loadingDirectories.add(node.path);

      try {
        await node.enumerateContents();
      } catch (e) {
        _logger.warning('Failed to load directory ${node.name}: $e');
      } finally {
        _loadingDirectories.remove(node.path);
      }
    }
  }

  Future<void> seedGitStatusForFile(ProjectNode node) async {
    if (projectRoot == null) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(projectRoot!.path);
      if (!isGitRepo) return;

      // Get Git status for this specific file
      final gitStatus = await _gitService.getStatus(projectRoot!.path);
      final relativePath = path.relative(node.path, from: projectRoot!.path);

      if (gitStatus.staged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.added;
      } else if (gitStatus.unstaged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.modified;
      } else if (gitStatus.untracked.contains(relativePath)) {
        node.gitStatus = GitFileStatus.untracked;
      } else {
        node.gitStatus = GitFileStatus.clean;
      }
    } catch (e) {
      _logger.severe('Error seeding Git status for file: $e');
    }
  }
}

/// Shared file operations utility
class FileOperations {
  static Future<void> createNewFile(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh,
  ) async {
    if (!parent.isDirectory) return;

    final TextEditingController controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File name',
            hintText: 'Enter file name (e.g., main.dart)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final newFilePath = path.join(parent.path, result);

      // Check if file already exists
      if (File(newFilePath).existsSync()) {
        MessageBox.showError(context, 'A file with this name already exists');
        return;
      }

      // Create the file
      final file = File(newFilePath);
      await file.create(recursive: true);

      // Refresh the project tree
      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, 'Created file "$result"');
      }
    } catch (e) {
      MessageBox.showError(context, 'Failed to create file: $e');
    }
  }

  static Future<void> createNewFolder(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh,
  ) async {
    if (!parent.isDirectory) return;

    final TextEditingController controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Enter folder name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final newFolderPath = path.join(parent.path, result);

      // Check if directory already exists
      if (Directory(newFolderPath).existsSync()) {
        MessageBox.showError(context, 'A folder with this name already exists');
        return;
      }

      // Create the directory
      final directory = Directory(newFolderPath);
      await directory.create(recursive: true);

      // Refresh the project tree
      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, 'Created folder "$result"');
      }
    } catch (e) {
      MessageBox.showError(context, 'Failed to create folder: $e');
    }
  }

  static Future<void> renameFile(
    BuildContext context,
    ProjectNode node,
    VoidCallback onRefresh,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: node.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'New name',
            hintText: 'Enter new ${node.isDirectory ? 'folder' : 'file'} name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == node.name) return;

    try {
      final newPath = path.join(path.dirname(node.path), result);

      // Check if target already exists
      if (File(newPath).existsSync() || Directory(newPath).existsSync()) {
        MessageBox.showError(
          context,
          'A file or folder with this name already exists',
        );
        return;
      }

      // Perform the rename operation
      if (node.isDirectory) {
        await Directory(node.path).rename(newPath);
      } else {
        await File(node.path).rename(newPath);
      }

      // Update the project tree
      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, 'Renamed to "$result"');
      }
    } catch (e) {
      MessageBox.showError(context, 'Failed to rename: $e');
    }
  }

  static Future<void> deleteFile(
    BuildContext context,
    ProjectNode node,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text(
          'Are you sure you want to delete "${node.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Perform the delete operation
      if (node.isDirectory) {
        await Directory(node.path).delete(recursive: true);
      } else {
        await File(node.path).delete();
      }

      // Refresh the project tree
      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, 'Deleted "${node.name}"');
      }
    } catch (e) {
      MessageBox.showError(context, 'Failed to delete: $e');
    }
  }

  static Future<void> revealInFileExplorer(ProjectNode node) async {
    try {
      final directoryPath = node.isDirectory
          ? node.path
          : path.dirname(node.path);

      if (Platform.isMacOS) {
        // Use 'open' command on macOS
        await Process.run('open', [directoryPath]);
      } else if (Platform.isWindows) {
        // Use 'explorer' command on Windows
        await Process.run('explorer', [directoryPath]);
      } else if (Platform.isLinux) {
        // Use 'xdg-open' command on Linux
        await Process.run('xdg-open', [directoryPath]);
      }
    } catch (e) {
      // Error handling will be done by caller
    }
  }
}

/// Shared context menu handler
class ContextMenuHandler {
  static void showNodeContextMenu(
    BuildContext context,
    ProjectNode node,
    Offset position,
    Function(String, ProjectNode) onAction,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        const PopupMenuItem(
          value: 'copy_full_path',
          child: Text('Copy Full Path'),
        ),
        const PopupMenuItem(
          value: 'copy_relative_path',
          child: Text('Copy Relative Path'),
        ),
        if (node.isDirectory) ...[
          const PopupMenuItem(value: 'new_file', child: Text('New File')),
          const PopupMenuItem(value: 'new_folder', child: Text('New Folder')),
        ],
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      onAction(value, node);
    });
  }

  static void showFileContextMenu(
    BuildContext context,
    ProjectNode node,
    Offset position,
    Function(String, ProjectNode) onAction,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'reveal',
          child: Row(
            children: [
              Icon(
                Platform.isMacOS ? Icons.folder_open : Icons.folder,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(Platform.isMacOS ? 'Reveal in Finder' : 'Show in Explorer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_full_path',
          child: Row(
            children: [
              Icon(
                Icons.content_copy,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Copy Full Path'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_relative_path',
          child: Row(
            children: [
              Icon(
                Icons.content_copy,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Copy Relative Path'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      onAction(value, node);
    });
  }
}
