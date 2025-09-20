// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/git_service.dart';

import 'base_panel.dart';

/// FolderPanel provides a filesystem-style view of the project
class FolderPanel extends BasePanel {
  const FolderPanel({
    super.key,
    super.onFileSelected,
    super.selectedFile,
    super.onThemeChanged,
    super.onProjectLoaded,
    super.onProjectPathChanged,
    super.initialProjectPath,
    super.showGitPanel = false,
    super.onToggleGitPanel,
  }) : super(panelMode: PanelMode.filesystem);

  @override
  BasePanelState<FolderPanel> createState() => FolderPanelState();
}

class FolderPanelState extends BasePanelState<FolderPanel> {
  final GitService _gitService = GitService();

  @override
  Widget buildPanelContent() {
    if (projectRoot == null) {
      return Container(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No project loaded'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: pickDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Project'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1.0,
              ),
            ),
          ),
          child: TextField(
            controller: filterController,
            decoration: InputDecoration(
              hintText: 'Filter files...',
              prefixIcon: const Icon(Icons.filter_list, size: 20),
              suffixIcon: filterQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        filterController.clear();
                        // Clear filter query by triggering the filter change listener
                        // This will be handled by the base class
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        // File tree
        Expanded(
          child: SingleChildScrollView(
            child: filterQuery.isEmpty
                ? Column(
                    children: projectRoot!.children
                        .map((node) => _buildNode(node))
                        .toList(),
                  )
                : _buildFilteredTree(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredTree() {
    if (projectRoot == null) return const SizedBox();

    // Build a filtered tree that preserves directory structure
    return Column(
      children: projectRoot!.children
          .where((node) => _hasMatchingDescendant(node) || _matchesFilter(node))
          .map((node) => _buildFilteredNode(node))
          .toList(),
    );
  }

  Widget _buildFilteredNode(ProjectNode node) {
    if (node.isDirectory) {
      return _buildFilteredDirectoryNode(node);
    } else {
      return _buildNode(node);
    }
  }

  Widget _buildFilteredDirectoryNode(ProjectNode node) {
    final isExpanded =
        expandedState[node.path] ?? true; // Auto-expand filtered directories
    final hasError =
        node.loadResult != null &&
        node.loadResult != LoadChildrenResult.success;

    // Determine text color based on hidden status and error status
    Color textColor;
    if (hasError) {
      textColor = Theme.of(context).colorScheme.error;
    } else if (node.isHidden) {
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    // Determine icon color
    Color iconColor;
    if (hasError) {
      iconColor = Theme.of(context).colorScheme.error;
    } else if (node.isHidden) {
      iconColor = Theme.of(context).colorScheme.primary.withOpacity(0.5);
    } else {
      iconColor = Theme.of(context).colorScheme.primary;
    }

    // Highlight directory if it matches the filter
    final isMatching = _matchesFilter(node);
    if (isMatching) {
      textColor = Theme.of(context).colorScheme.primary;
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _onFilteredNodeTapped(node, isExpanded),
          onLongPressStart: (details) =>
              _showFilteredNodeContextMenu(node, details.globalPosition),
          child: Container(
            color: isMatching
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.1)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              child: Row(
                children: [
                  Icon(
                    hasError ? Icons.folder_off : Icons.folder,
                    color: iconColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: isMatching
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(width: 4),
                    Icon(
                      node.loadResult == LoadChildrenResult.accessDenied
                          ? Icons.lock
                          : Icons.error,
                      color: Theme.of(context).colorScheme.error,
                      size: 14,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (node.isDirectory && isExpanded)
          Padding(
            padding: EdgeInsets.only(left: node.children.isEmpty ? 32 : 16.0),
            child: node.children.isEmpty
                ? const Text(
                    'empty folder',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  )
                : _buildFilteredNodeChildren(node),
          ),
      ],
    );
  }

  Widget _buildFilteredNodeChildren(ProjectNode node) {
    // Deduplicate children by path to prevent duplicate entries
    final uniqueChildren = <String, ProjectNode>{};
    for (final child in node.children) {
      uniqueChildren[child.path] = child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: uniqueChildren.values
          .where(
            (child) => _hasMatchingDescendant(child) || _matchesFilter(child),
          )
          .map((child) => _buildFilteredNode(child))
          .toList(),
    );
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

  // Helper method to check if node matches filter
  bool _matchesFilter(ProjectNode node) {
    if (filterQuery.isEmpty) return true;
    return node.name.toLowerCase().contains(filterQuery);
  }

  void _onFilteredNodeTapped(ProjectNode node, bool isExpanded) async {
    if (node.isDirectory) {
      if (mounted) {
        setState(() {
          expandedState[node.path] = !isExpanded;
        });
      }

      if (!isExpanded && node.children.isEmpty) {
        try {
          await node.enumerateContents();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          if (e.toString().contains('Operation not permitted') ||
              e.toString().contains('Permission denied')) {
            showError('Access denied: ${node.name}');
          } else {
            showError('Failed to load directory: $e');
          }
        }
      }
    } else {
      // Handle file tap by calling the file selection callback
      final item = FileSystemItem.fromFileSystemEntity(File(node.path));
      if (widget.selectedFile?.path == item.path) return;

      // Seed Git status for the selected file if not already loaded
      if (node.gitStatus == GitFileStatus.clean && projectRoot != null) {
        _seedGitStatusForFile(node);
      }

      // Trigger file selection if callback is provided
      if (widget.onFileSelected != null && mounted) {
        widget.onFileSelected!(item);
      }
    }
  }

  void _showFilteredNodeContextMenu(ProjectNode node, Offset position) {
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
      _handleFilteredContextMenuAction(value, node);
    });
  }

  void _handleFilteredContextMenuAction(String action, ProjectNode node) {
    debugPrint(
      '📋 FolderPanel: Handling filtered context menu action: $action for ${node.name}',
    );
    switch (action) {
      case 'open':
        _onFilteredNodeTapped(node, expandedState[node.path] ?? false);
        break;
      case 'new_file':
        debugPrint('📄 Creating new file in ${node.path}');
        _createNewFile(node);
        break;
      case 'new_folder':
        debugPrint('📁 Creating new folder in ${node.path}');
        _createNewFolder(node);
        break;
      case 'rename':
        _renameFile(node);
        break;
      case 'delete':
        _deleteFile(node);
        break;
    }
  }

  @override
  void _handleContextMenuAction(String action, ProjectNode node) {
    debugPrint(
      '🔄 FolderPanel: _handleContextMenuAction OVERRIDE called with action: $action for ${node.name}',
    );
    // Override the base class method to use our implementations
    switch (action) {
      case 'open':
        _onFilteredNodeTapped(node, expandedState[node.path] ?? false);
        break;
      case 'new_file':
        debugPrint('📄 FolderPanel: Calling _createNewFile for ${node.name}');
        _createNewFile(node);
        break;
      case 'new_folder':
        debugPrint('📁 FolderPanel: Calling _createNewFolder for ${node.name}');
        _createNewFolder(node);
        break;
      case 'rename':
        _renameFile(node);
        break;
      case 'delete':
        _deleteFile(node);
        break;
      default:
        debugPrint('❌ FolderPanel: Unknown action: $action');
        break;
    }
  }

  Future<void> _seedGitStatusForFile(ProjectNode node) async {
    if (projectRoot == null || !mounted) return;

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

      // Trigger UI update only if still mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Silently handle errors
      debugPrint('Error seeding Git status for file: $e');
    }
  }

  // Helper method to build node widget
  Widget _buildNode(ProjectNode node) {
    if (node.isDirectory) {
      return buildDirectoryNode(node);
    } else {
      return buildFileNode(node);
    }
  }

  // File operations implementation
  Future<void> _createNewFile(ProjectNode parent) async {
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
        showError('A file with this name already exists');
        return;
      }

      // Create the file
      final file = File(newFilePath);
      await file.create(recursive: true);

      // Refresh the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Created file "$result"')));
      }
    } catch (e) {
      showError('Failed to create file: $e');
    }
  }

  Future<void> _createNewFolder(ProjectNode parent) async {
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
        showError('A folder with this name already exists');
        return;
      }

      // Create the directory
      final directory = Directory(newFolderPath);
      await directory.create(recursive: true);

      // Refresh the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Created folder "$result"')));
      }
    } catch (e) {
      showError('Failed to create folder: $e');
    }
  }

  Future<void> _renameFile(ProjectNode node) async {
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
        showError('A file or folder with this name already exists');
        return;
      }

      // Perform the rename operation
      if (node.isDirectory) {
        await Directory(node.path).rename(newPath);
      } else {
        await File(node.path).rename(newPath);
      }

      // Refresh the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$result"')));
      }
    } catch (e) {
      showError('Failed to rename: $e');
    }
  }

  Future<void> _deleteFile(ProjectNode node) async {
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
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${node.name}"')));
      }
    } catch (e) {
      showError('Failed to delete: $e');
    }
  }

  Future<void> _refreshProjectTree() async {
    if (projectRoot == null) return;

    try {
      // Reload the project tree recursively
      final result = await projectRoot!.enumerateContentsRecursive();

      if (result == LoadChildrenResult.success && mounted) {
        setState(() {});
      }
    } catch (e) {
      showError('Failed to refresh project tree: $e');
    }
  }
}
