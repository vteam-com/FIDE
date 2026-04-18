// ignore_for_file:  avoid_print

import 'dart:io';

import 'package:fide/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/utils/message_box.dart';
import 'package:fide/widgets/filename_widget.dart';
import 'package:fide/widgets/foldername_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

part 'folder_panel.node_builder.dart';

/// FolderPanel provides a filesystem-style view of the project
class FolderPanel extends ConsumerStatefulWidget {
  const FolderPanel({
    super.key,
    this.onFileSelected,
    this.selectedFile,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.onProjectPathChanged,
    this.initialProjectPath,
    this.onToggleGitPanel,
  });

  final String? initialProjectPath;
  final Function(FileSystemItem)? onFileSelected;
  final Function(bool)? onProjectLoaded;
  final Function(String)? onProjectPathChanged;
  final Function(ThemeMode)? onThemeChanged;
  final VoidCallback? onToggleGitPanel;
  final FileSystemItem? selectedFile;

  @override
  ConsumerState<FolderPanel> createState() => _FolderPanelState();
}

class _FolderPanelState extends ConsumerState<FolderPanel> {
  final Logger _logger = Logger('FolderPanelState');
  final PanelStateManager _panelState = PanelStateManager();
  final GitService _gitService = GitService();

  // Performance optimization caches
  final Map<String, FileSystemItem> _cachedFileSystemItems = {};

  @override
  void initState() {
    super.initState();
    _panelState.initialize();
  }

  @override
  void dispose() {
    _panelState.dispose();
    super.dispose();
  }

  // Getters for panel state
  /// Returns `projectRoot`.
  ProjectNode? get projectRoot => _panelState.projectRoot;

  /// Returns `filterController`.
  TextEditingController get filterController => _panelState.filterController;

  /// Returns `filterQuery`.
  String get filterQuery => _panelState.filterQuery;

  /// Returns `expandedState`.
  Map<String, bool> get expandedState => _panelState.expandedState;

  // Helper methods
  /// Handles `_FolderPanelState.showError`.
  void showError(String message) {
    MessageBox.showError(context, message, showCopyButton: true);
  }

  /// Handles `_FolderPanelState.pickDirectory`.
  Future<void> pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        showError('Project loading is handled by the main application');
      }
    } catch (e) {
      showError('Error selecting directory: $e');
    }
  }

  // Cached FileSystemItem getter to avoid expensive object creation
  FileSystemItem _getCachedFileSystemItem(
    String path,
    GitFileStatus gitStatus,
  ) {
    final cacheKey = '${path}_${gitStatus.index}';
    if (_cachedFileSystemItems.containsKey(cacheKey)) {
      return _cachedFileSystemItems[cacheKey]!;
    }

    final item = FileSystemItem.fromFileSystemEntity(File(path));
    item.gitStatus = gitStatus;
    _cachedFileSystemItems[cacheKey] = item;
    return item;
  }

  void _handleFileSelection(ProjectNode node) {
    final item = _getCachedFileSystemItem(node.path, node.gitStatus);
    // Only select files for editing, not folders
    if (widget.onFileSelected != null && node.isFile) {
      widget.onFileSelected!(item);
    }
  }

  /// Handles `_ensureSelectedFileVisible`.
  void _ensureSelectedFileVisible(String filePath) {
    if (_panelState.projectRoot == null || !mounted) return;

    // For filesystem view, expand the directory containing the file
    final fileDir = path.dirname(filePath);
    if (fileDir != _panelState.projectRoot!.path) {
      /// Handles `_findNodeByPath`.
      final directoryNode = _findNodeByPath(fileDir);
      if (directoryNode != null && mounted) {
        setState(() {
          _panelState.expandedState[fileDir] = true;
        });
      }
    }
  }

  /// Handles `_onNodeTapped`.
  void _onNodeTapped(ProjectNode node, bool isExpanded) async {
    if (node.isDirectory) {
      // Directory can be selected for navigation/display purposes, not for opening in editor
      // We'll keep directory selection for UI state but not open them in editor
      // (This maintains the UI feedback when directory is tapped)

      // Handle expansion/collapse
      if (mounted) {
        setState(() {
          _panelState.expandedState[node.path] = !isExpanded;
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
      /// Handles `_handleFileTap`.
      _handleFileTap(node);
    }
  }

  /// Handles `_handleFileTap`.
  void _handleFileTap(ProjectNode node) {
    FileOperations.handleFileTap(
      node,
      _panelState,
      selectedFilePath: widget.selectedFile?.path,
      onFileSelected: widget.onFileSelected,
      isMounted: mounted,
    );
  }

  void _showNodeContextMenu(ProjectNode node, Offset position) {
    ContextMenuHandler.showNodeContextMenu(
      context,
      node,
      position,
      _handleContextMenuAction,
    );
  }

  void _showFileContextMenu(ProjectNode node, Offset position) {
    ContextMenuHandler.showFileContextMenu(
      context,
      node,
      position,
      _handleFileContextMenuAction,
    );
  }

  /// Handles `_handleContextMenuAction`.
  void _handleContextMenuAction(String action, ProjectNode node) {
    switch (action) {
      case 'open':
        _onNodeTapped(node, _panelState.expandedState[node.path] ?? false);
        break;
      case 'new_file':
        FileOperations.createNewFile(context, node, _refreshProjectTree);
        break;
      case 'new_folder':
        FileOperations.createNewFolder(context, node, _refreshProjectTree);
        break;
      case 'rename':
        FileOperations.renameFile(context, node, _refreshProjectTree);
        break;
      case 'delete':
        FileOperations.deleteFile(context, node, _refreshProjectTree);
        break;
    }
  }

  /// Handles `_handleFileContextMenuAction`.
  void _handleFileContextMenuAction(String action, ProjectNode node) {
    switch (action) {
      case 'reveal':
        FileOperations.revealInFileExplorer(node);
        break;
      case 'copy_full_path':
        Clipboard.setData(ClipboardData(text: node.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Full path copied to clipboard')),
          );
        }
        break;
      case 'copy_relative_path':
        if (projectRoot != null) {
          final relative = path.relative(node.path, from: projectRoot!.path);
          Clipboard.setData(ClipboardData(text: relative));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Relative path copied to clipboard'),
              ),
            );
          }
        }
        break;
      case 'rename':
        FileOperations.renameFile(context, node, _refreshProjectTree);
        break;
      case 'delete':
        FileOperations.deleteFile(context, node, _refreshProjectTree);
        break;
    }
  }

  /// Handles `_findNodeByPath`.
  ProjectNode? _findNodeByPath(String targetPath) {
    if (_panelState.projectRoot == null) return null;

    // Helper function to search recursively
    ProjectNode? findInNode(ProjectNode node) {
      if (node.path == targetPath) {
        return node;
      }

      for (final child in node.children) {
        final found = findInNode(child);
        if (found != null) {
          return found;
        }
      }

      return null;
    }

    return findInNode(_panelState.projectRoot!);
  }

  /// Handles `_refreshProjectTree`.
  Future<void> _refreshProjectTree() async {
    if (_panelState.projectRoot == null) return;

    try {
      // Reload the project tree recursively
      await _panelState.projectRoot!.enumerateContentsRecursive();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showError('Failed to refresh project tree: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);

    // Update local state when project data changes
    if (currentProjectRoot != _panelState.projectRoot) {
      if (mounted) {
        setState(() {
          _panelState.projectRoot = currentProjectRoot;
          // Clear expanded state when project changes
          _panelState.expandedState.clear();
          // Clear caches when project changes
          _cachedFileSystemItems.clear();
        });
      }
    }

    // Ensure selected file is expanded and visible when building
    if (widget.selectedFile != null && _panelState.projectRoot != null) {
      // Use a microtask to ensure this happens after the current build cycle
      Future.microtask(() {
        if (mounted) {
          _ensureSelectedFileVisible(widget.selectedFile!.path);
        }
      });
    }

    return !isProjectLoaded
        ? Container(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(
              child: Text(
                'No project loaded',
                style: TextStyle(fontSize: AppFontSize.title),
              ),
            ),
          )
        : buildPanelContent();
  }

  /// Handles `_FolderPanelState.buildPanelContent`.
  Widget buildPanelContent() {
    if (projectRoot == null) {
      return Container(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_open,
                size: AppIconSize.emptyState,
                color: Colors.grey,
              ),
              const SizedBox(height: AppSpacing.xLarge),
              const Text('No project loaded'),
              const SizedBox(height: AppSpacing.medium),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isConstrained = constraints.maxHeight.isFinite;

        return Column(
          children: [
            // File tree
            if (isConstrained)
              Expanded(
                child: SingleChildScrollView(
                  child: filterQuery.isEmpty
                      ? Column(
                          children: projectRoot!.children
                              .map((node) => _buildNode(node))
                              .toList(),
                        )
                      /// Handles `_buildFilteredTree`.
                      : _buildFilteredTree(),
                ),
              )
            else
              SizedBox(
                height: AppSize.folderPanelFallbackHeight,
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
            // Filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                0,
                AppSpacing.medium,
                AppSpacing.medium,
              ),
              child: TextField(
                controller: filterController,
                decoration: InputDecoration(
                  hintText: 'Filter...',
                  prefixIcon: const Icon(
                    Icons.filter_list,
                    size: AppIconSize.large,
                  ),
                  suffixIcon: filterQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: AppIconSize.large,
                          ),
                          onPressed: () {
                            filterController.clear();
                            // Clear filter query by triggering the filter change listener
                            // This will be handled by the base class
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                    vertical: AppSpacing.medium,
                  ),
                ),
                style: const TextStyle(fontSize: AppFontSize.body),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handles `_buildFilteredTree`.
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
      /// Handles `_buildFilteredDirectoryNode`.
      return _buildFilteredDirectoryNode(node);
    } else {
      return _buildNode(node);
    }
  }

  /// Handles `_buildFilteredDirectoryNode`.
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
      textColor = Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: AppOpacity.disabled);
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    // Determine icon color
    Color iconColor;
    if (hasError) {
      iconColor = Theme.of(context).colorScheme.error;
    } else if (node.isHidden) {
      iconColor = Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: AppOpacity.disabled);
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
              /// Handles `_showFilteredNodeContextMenu`.
              _showFilteredNodeContextMenu(node, details.globalPosition),
          child: Container(
            color: isMatching
                ? Theme.of(context).colorScheme.primaryContainer.withValues(
                    alpha: AppOpacity.subtle,
                  )
                : null,
            child: Padding(
              padding: AppPadding.listItem,
              child: Row(
                children: [
                  Icon(
                    hasError ? Icons.folder_off : Icons.folder,
                    color: iconColor,
                    size: AppIconSize.medium,
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        color: textColor,
                        fontWeight: isMatching
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(width: AppSpacing.tiny),
                    Icon(
                      node.loadResult == LoadChildrenResult.accessDenied
                          ? Icons.lock
                          : Icons.error,
                      color: Theme.of(context).colorScheme.error,
                      size: AppIconSize.small,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (node.isDirectory && isExpanded)
          Padding(
            padding: EdgeInsets.only(
              left: node.children.isEmpty
                  ? AppSize.compactActionButton
                  : AppSpacing.xLarge,
            ),
            child: node.children.isEmpty
                ? const Text(
                    'empty folder',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                      fontSize: AppFontSize.caption,
                    ),
                  )
                /// Handles `_buildFilteredNodeChildren`.
                : _buildFilteredNodeChildren(node),
          ),
      ],
    );
  }

  /// Handles `_buildFilteredNodeChildren`.
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

  /// Handles `_onFilteredNodeTapped`.
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
        /// Handles `_seedGitStatusForFile`.
        _seedGitStatusForFile(node);
      }

      // Trigger file selection if callback is provided
      if (widget.onFileSelected != null && mounted) {
        widget.onFileSelected!(item);
      }
    }
  }

  /// Handles `_showFilteredNodeContextMenu`.
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

      /// Handles `_handleFilteredContextMenuAction`.
      _handleFilteredContextMenuAction(value, node);
    });
  }

  /// Handles `_handleFilteredContextMenuAction`.
  void _handleFilteredContextMenuAction(String action, ProjectNode node) {
    _logger.info(
      'Handling filtered context menu action: $action for ${node.name}',
    );
    switch (action) {
      case 'open':
        _onFilteredNodeTapped(node, expandedState[node.path] ?? false);
        break;
      case 'new_file':
        _logger.info('Creating new file in ${node.path}');
        _createNewFile(node);
        break;
      case 'new_folder':
        _logger.info('Creating new folder in ${node.path}');

        /// Handles `_createNewFolder`.
        _createNewFolder(node);
        break;
      case 'rename':

        /// Handles `_renameFile`.
        _renameFile(node);
        break;
      case 'delete':

        /// Handles `_deleteFile`.
        _deleteFile(node);
        break;
    }
  }

  /// Handles `_seedGitStatusForFile`.
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
      _logger.severe('Error seeding Git status for file: $e');
    }
  }

  // Helper method to build node widget
  Widget _buildNode(ProjectNode node) {
    return NodeBuilder(
      node: node,
      selectedFile: widget.selectedFile,
      expandedState: _panelState.expandedState,
      rootPath: projectRoot!.path,
      onNodeTapped: _onNodeTapped,
      onShowContextMenu: _showNodeContextMenu,
      onShowFileContextMenu: _showFileContextMenu,
      onFileSelected: _handleFileSelection,
    );
  }

  // File operations implementation
  Future<void> _createNewFile(ProjectNode parent) async {
    await FileOperations.createNewFile(context, parent, _refreshProjectTree);
  }

  /// Handles `_createNewFolder`.
  Future<void> _createNewFolder(ProjectNode parent) async {
    await FileOperations.createNewFolder(context, parent, _refreshProjectTree);
  }

  /// Handles `_renameFile`.
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
        MessageBox.showSuccess(context, 'Renamed to "$result"');
      }
    } catch (e) {
      showError('Failed to rename: $e');
    }
  }

  /// Handles `_deleteFile`.
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
        MessageBox.showSuccess(context, 'Deleted "${node.name}"');
      }
    } catch (e) {
      showError('Failed to delete: $e');
    }
  }
}
