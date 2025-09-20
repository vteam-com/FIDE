// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/utils/message_helper.dart';

// Widgets
import 'git_panel.dart';
import 'folder_panel.dart';

// Providers
import '../../providers/app_providers.dart';

enum PanelMode { filesystem, organized }

/// Base class containing shared functionality for FolderPanel and OrganizedPanel
abstract class BasePanel extends ConsumerStatefulWidget {
  const BasePanel({
    super.key,
    this.onFileSelected,
    this.selectedFile,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.onProjectPathChanged,
    this.initialProjectPath,
    this.showGitPanel = false,
    this.onToggleGitPanel,
    required this.panelMode,
  });

  final String? initialProjectPath;
  final Function(FileSystemItem)? onFileSelected;
  final Function(bool)? onProjectLoaded;
  final Function(String)? onProjectPathChanged;
  final Function(ThemeMode)? onThemeChanged;
  final VoidCallback? onToggleGitPanel;
  final FileSystemItem? selectedFile;
  final bool showGitPanel;
  final PanelMode panelMode;
}

abstract class BasePanelState<T extends BasePanel> extends ConsumerState<T> {
  final Map<String, bool> _expandedState = {};
  final GitService _gitService = GitService();
  final bool _isLoading = false;
  final Set<String> _loadingDirectories = {};
  ProjectNode? _projectRoot;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  // Protected getters for subclasses
  @protected
  ProjectNode? get projectRoot => _projectRoot;

  @protected
  TextEditingController get filterController => _filterController;

  @protected
  String get filterQuery => _filterQuery;

  @protected
  Map<String, bool> get expandedState => _expandedState;

  // Protected methods for subclasses
  @protected
  Widget buildDirectoryNode(ProjectNode node) => _buildDirectoryNode(node);

  @protected
  Widget buildFileNode(ProjectNode node) => _buildFileNode(node);

  @protected
  Future<void> pickDirectory() => _pickDirectory();

  @protected
  void showError(String message) => _showError(message);

  @protected
  Future<void> ensureDirectoryLoaded(ProjectNode node) =>
      _ensureDirectoryLoaded(node);

  @override
  void initState() {
    super.initState();
    _initializeExplorer();
    _filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {
      _filterQuery = _filterController.text.toLowerCase();
      // Clear expansion state when filter changes
      _expandedState.clear();
      // Expand directories that contain matching files when filtering
      if (_filterQuery.isNotEmpty && _projectRoot != null) {
        _expandDirectoriesWithMatchingFiles(_projectRoot!);
      }
    });
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

    // Only show items whose names contain the filter query
    return node.name.toLowerCase().contains(_filterQuery);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If selectedFile changed, expand the tree to show it
    if (widget.selectedFile != oldWidget.selectedFile &&
        widget.selectedFile != null &&
        _projectRoot != null) {
      _expandToFile(widget.selectedFile!.path);
    } else if (widget.selectedFile != oldWidget.selectedFile) {
      // Force a rebuild to update selection highlighting even if project isn't loaded yet
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);

    // Update local state when project data changes
    if (currentProjectRoot != _projectRoot) {
      debugPrint(
        'BasePanel: Project changed from ${_projectRoot?.path} to ${currentProjectRoot?.path}',
      );
      // Use setState to trigger UI rebuild when project changes
      if (mounted) {
        setState(() {
          _projectRoot = currentProjectRoot;
          // Clear expanded state when project changes
          _expandedState.clear();
          debugPrint('BasePanel: State updated, triggering UI rebuild');
        });
      }
    }

    // Ensure selected file is expanded and visible when building
    if (widget.selectedFile != null && _projectRoot != null && !_isLoading) {
      // Use a microtask to ensure this happens after the current build cycle
      Future.microtask(() {
        if (mounted) {
          _expandToFile(widget.selectedFile!.path);
        }
      });
    }

    return !isProjectLoaded
        ? Container(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(
              child: Text('No project loaded', style: TextStyle(fontSize: 16)),
            ),
          )
        : widget.showGitPanel
        ? _buildGitPanel()
        : buildPanelContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also check for selected file when dependencies change
    if (widget.selectedFile != null && _projectRoot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _expandToFile(widget.selectedFile!.path);
      });
    }
  }

  // Abstract method to be implemented by subclasses
  Widget buildPanelContent();

  Widget _buildDirectoryNode(ProjectNode node) {
    final isExpanded = _expandedState[node.path] ?? false;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _onNodeTapped(node, _expandedState[node.path] ?? false),
          onLongPressStart: (details) =>
              _showNodeContextMenu(node, details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
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
                    style: TextStyle(fontSize: 13, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Context menu button for expanded directories
                if (isExpanded && !hasError) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTapDown: (details) =>
                        _showNodeContextMenu(node, details.globalPosition),
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
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
                : _buildNodeChildren(node),
          ),
      ],
    );
  }

  Widget _buildFileNode(ProjectNode node) {
    // More robust path comparison using path normalization
    final isSelected =
        widget.selectedFile != null &&
        (widget.selectedFile!.path == node.path ||
            path.normalize(widget.selectedFile!.path) ==
                path.normalize(node.path) ||
            path.canonicalize(widget.selectedFile!.path) ==
                path.canonicalize(node.path));

    // Get Git status styling
    final gitTextStyle = node.getGitStatusTextStyle(context);
    final badgeText = node.getGitStatusBadge();

    // Determine text color based on selection, hidden status, and Git status
    Color textColor;
    if (isSelected) {
      textColor = Theme.of(context).colorScheme.primary;
    } else if (node.isHidden) {
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    } else {
      textColor = gitTextStyle.color ?? Theme.of(context).colorScheme.onSurface;
    }

    // Determine background color for selection
    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = Theme.of(
        context,
      ).colorScheme.primaryContainer.withOpacity(0.3);
    }

    return GestureDetector(
      onTap: () => _handleFileTap(node),
      onLongPressStart: (details) =>
          _showNodeContextMenu(node, details.globalPosition),
      child: Container(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Row(
            children: [
              _getFileIcon(node),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: gitTextStyle.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Git status indicator
              if (badgeText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: node.getGitStatusColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: node.getGitStatusColor(context),
                    ),
                  ),
                ),
              // Context menu button for selected files
              if (isSelected) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTapDown: (details) =>
                      _showFileContextMenu(node, details.globalPosition),
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.more_vert,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGitPanel() {
    if (_projectRoot == null) {
      return const Center(child: Text('No project loaded'));
    }

    return SizedBox.expand(child: GitPanel(projectPath: _projectRoot!.path));
  }

  Widget _buildNode(ProjectNode node) {
    if (node.isDirectory) {
      return _buildDirectoryNode(node);
    } else {
      return _buildFileNode(node);
    }
  }

  Widget _buildNodeChildren(ProjectNode node) {
    // Deduplicate children by path to prevent duplicate entries
    final uniqueChildren = <String, ProjectNode>{};
    for (final child in node.children) {
      uniqueChildren[child.path] = child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: uniqueChildren.values
          .where((child) => _matchesFilter(child))
          .map((child) => _buildNode(child))
          .toList(),
    );
  }

  Future<void> _createNewFile(ProjectNode parent) async {}

  Future<void> _createNewFolder(ProjectNode parent) async {}

  // FolderPanel-specific implementations
  Future<void> _createNewFileForFolderPanel(ProjectNode parent) async {
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
        _showError('A file with this name already exists');
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
      _showError('Failed to create file: $e');
    }
  }

  Future<void> _createNewFolderForFolderPanel(ProjectNode parent) async {
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
        _showError('A folder with this name already exists');
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
      _showError('Failed to create folder: $e');
    }
  }

  Future<void> _renameFileForFolderPanel(ProjectNode node) async {
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
        _showError('A file or folder with this name already exists');
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
      _showError('Failed to rename: $e');
    }
  }

  Future<void> _deleteFileForFolderPanel(ProjectNode node) async {
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
      _showError('Failed to delete: $e');
    }
  }

  Future<void> _deleteFile(ProjectNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
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

      // Update the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${node.name}"')));
      }
    } catch (e) {
      _showError('Failed to delete file: $e');
    }
  }

  Future<void> _ensureDirectoryLoaded(ProjectNode node) async {
    if (node.children.isEmpty && node.isDirectory) {
      // Mark this directory as loading
      _loadingDirectories.add(node.path);

      try {
        await node.enumerateContents();

        // Trigger rebuild when enumeration is complete
        if (mounted) {
          setState(() {
            _loadingDirectories.remove(node.path);
          });
        }
      } catch (e) {
        // Silently handle errors for organized view - don't show error messages
        // The directory will just appear empty in the organized view
        debugPrint(
          'Failed to load directory ${node.name} for organized view: $e',
        );

        // Remove from loading set even on error
        if (mounted) {
          setState(() {
            _loadingDirectories.remove(node.path);
          });
        }
      }
    }
  }

  void _ensureSelectedFileVisible(String filePath) {
    if (_projectRoot == null || !mounted) return;

    // For organized view, just expand the relevant category
    if (widget.panelMode == PanelMode.organized) {
      final relativePath = path.relative(filePath, from: _projectRoot!.path);
      String targetCategory = 'Root';

      if (relativePath.startsWith('lib/')) {
        targetCategory = 'Lib';
      } else if (relativePath.startsWith('test/')) {
        targetCategory = 'Tests';
      } else if (relativePath.startsWith('assets/')) {
        targetCategory = 'Assets';
      } else if (relativePath.startsWith('android/') ||
          relativePath.startsWith('ios/') ||
          relativePath.startsWith('web/') ||
          relativePath.startsWith('windows/') ||
          relativePath.startsWith('macos/') ||
          relativePath.startsWith('linux/')) {
        targetCategory = 'Platforms';
      } else if (relativePath.startsWith('build/') ||
          relativePath.startsWith('.dart_tool/') ||
          relativePath.startsWith('benchmark/')) {
        targetCategory = 'Output';
      }

      if (mounted) {
        setState(() {
          _expandedState['category_$targetCategory'] = true;
        });
      }
    } else {
      // For filesystem view, expand the directory containing the file
      final fileDir = path.dirname(filePath);
      if (fileDir != _projectRoot!.path) {
        final directoryNode = _findNodeByPath(fileDir);
        if (directoryNode != null && mounted) {
          setState(() {
            _expandedState[fileDir] = true;
          });
        }
      }
    }
  }

  void _expandToFile(String filePath) {
    if (_projectRoot == null || !mounted) return;

    // Get the relative path from project root
    final relativePath = path.relative(filePath, from: _projectRoot!.path);

    // For organized view, expand the relevant category
    if (widget.panelMode == PanelMode.organized) {
      String targetCategory = 'Root';

      if (relativePath.startsWith('lib/')) {
        targetCategory = 'Lib';
      } else if (relativePath.startsWith('test/')) {
        targetCategory = 'Tests';
      } else if (relativePath.startsWith('assets/')) {
        targetCategory = 'Assets';
      } else if (relativePath.startsWith('android/') ||
          relativePath.startsWith('ios/') ||
          relativePath.startsWith('web/') ||
          relativePath.startsWith('windows/') ||
          relativePath.startsWith('macos/') ||
          relativePath.startsWith('linux/')) {
        targetCategory = 'Platforms';
      } else if (relativePath.startsWith('build/') ||
          relativePath.startsWith('.dart_tool/') ||
          relativePath.startsWith('benchmark/')) {
        targetCategory = 'Output';
      }

      // Only expand the category if it's not already expanded (respect user choice)
      if (_expandedState['category_$targetCategory'] != false && mounted) {
        setState(() {
          _expandedState['category_$targetCategory'] = true;
        });
      }

      // Ensure the directory containing the file is loaded
      final fileDir = path.dirname(filePath);
      if (fileDir != _projectRoot!.path) {
        final directoryNode = _findNodeByPath(fileDir);
        if (directoryNode != null && directoryNode.children.isEmpty) {
          _ensureDirectoryLoaded(directoryNode);
        }
      }
    } else {
      // For filesystem view, expand directories but respect user choices
      final pathComponents = path.split(relativePath);
      String currentPath = _projectRoot!.path;

      for (final component in pathComponents) {
        if (component == path.basename(filePath)) {
          // This is the file itself, not a directory
          break;
        }

        currentPath = path.join(currentPath, component);

        // Only expand if not explicitly collapsed by user
        if (_expandedState[currentPath] != false && mounted) {
          setState(() {
            _expandedState[currentPath] = true;
          });
        }

        // Find the directory node and ensure it's loaded
        final directoryNode = _findNodeByPath(currentPath);
        if (directoryNode != null && directoryNode.children.isEmpty) {
          _ensureDirectoryLoaded(directoryNode);
        }
      }
    }

    // Ensure the selected file is visible and scroll to it after a short delay to allow the tree to expand
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureSelectedFileVisible(filePath);
        }
      });
    }
  }

  ProjectNode? _findNodeByPath(String targetPath) {
    if (_projectRoot == null) return null;

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

    return findInNode(_projectRoot!);
  }

  Widget _getFileIcon(ProjectNode node) {
    final colorScheme = Theme.of(context).colorScheme;

    if (node.isDirectory) {
      return Icon(Icons.folder, color: colorScheme.primary, size: 16);
    }

    final ext = node.fileExtension?.toLowerCase() ?? '';
    switch (ext) {
      case '.dart':
        return Icon(Icons.code, color: colorScheme.primary, size: 16);
      case '.yaml':
      case '.yml':
        return Icon(Icons.settings, color: colorScheme.secondary, size: 16);
      case '.md':
        return Icon(Icons.article, color: colorScheme.secondary, size: 16);
      case '.txt':
        return Icon(
          Icons.article,
          color: colorScheme.onSurfaceVariant,
          size: 16,
        );
      case '.js':
        return Icon(Icons.javascript, color: colorScheme.tertiary, size: 16);
      case '.py':
        return Icon(Icons.code, color: colorScheme.primary, size: 16);
      case '.java':
      case '.kt':
        return Icon(Icons.code, color: colorScheme.tertiary, size: 16);
      case '.gradle':
        return Icon(Icons.build, color: colorScheme.onSurfaceVariant, size: 16);
      case '.xml':
      case '.html':
        return Icon(Icons.code, color: colorScheme.tertiary, size: 16);
      case '.css':
        return Icon(Icons.css, color: colorScheme.primary, size: 16);
      case '.json':
        return Icon(Icons.data_object, color: colorScheme.tertiary, size: 16);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
        return Icon(Icons.image, color: colorScheme.tertiary, size: 16);
      case '.pdf':
        return Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 16);
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icon(Icons.archive, color: colorScheme.secondary, size: 16);
      default:
        return Icon(
          Icons.insert_drive_file,
          color: colorScheme.onSurfaceVariant,
          size: 16,
        );
    }
  }

  void _handleContextMenuAction(String action, ProjectNode node) {
    debugPrint(
      '🏠 BasePanel: _handleContextMenuAction called with action: $action for ${node.name} (this.runtimeType: ${this.runtimeType})',
    );

    // Check if this is a FolderPanel and delegate to its implementation
    if (this.runtimeType.toString() == 'FolderPanelState') {
      debugPrint(
        '🏠 BasePanel: Detected FolderPanelState, delegating to FolderPanel implementation',
      );
      // Since we can't cast directly, we'll handle the FolderPanel logic here
      switch (action) {
        case 'open':
          _onNodeTapped(node, _expandedState[node.path] ?? false);
          break;
        case 'new_file':
          debugPrint('🏠 BasePanel: Delegating _createNewFile to FolderPanel');
          _createNewFileForFolderPanel(node);
          break;
        case 'new_folder':
          debugPrint(
            '🏠 BasePanel: Delegating _createNewFolder to FolderPanel',
          );
          _createNewFolderForFolderPanel(node);
          break;
        case 'rename':
          _renameFileForFolderPanel(node);
          break;
        case 'delete':
          _deleteFileForFolderPanel(node);
          break;
      }
      return;
    }

    switch (action) {
      case 'open':
        _onNodeTapped(node, _expandedState[node.path] ?? false);
        break;
      case 'new_file':
        debugPrint('🏠 BasePanel: Calling _createNewFile');
        _createNewFile(node);
        break;
      case 'new_folder':
        debugPrint('🏠 BasePanel: Calling _createNewFolder');
        _createNewFolder(node);
        break;
      case 'rename':
        debugPrint('🏠 BasePanel: Calling _renameFile');
        _renameFile(node);
        break;
      case 'delete':
        debugPrint('🏠 BasePanel: Calling _deleteFile');
        _deleteFile(node);
        break;
    }
  }

  void _handleFileContextMenuAction(String action, ProjectNode node) {
    switch (action) {
      case 'reveal':
        _revealInFileExplorer(node);
        break;
      case 'rename':
        _renameFile(node);
        break;
      case 'delete':
        _deleteFile(node);
        break;
    }
  }

  void _handleFileTap(ProjectNode node) {
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    if (widget.selectedFile?.path == item.path) return;

    // Seed Git status for the selected file if not already loaded
    if (node.gitStatus == GitFileStatus.clean && _projectRoot != null) {
      _seedGitStatusForFile(node);
    }

    // Only trigger file selection if widget is still mounted
    if (widget.onFileSelected != null && mounted) {
      widget.onFileSelected!(item);
    }
  }

  Future<void> _initializeExplorer() async {
    // Project loading is now handled by ProjectService
    // BasePanel only consumes the loaded project data
  }

  void _onNodeTapped(ProjectNode node, bool isExpanded) async {
    if (node.isDirectory) {
      if (mounted) {
        setState(() {
          _expandedState[node.path] = !isExpanded;
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
            _showError('Access denied: ${node.name}');
          } else {
            _showError('Failed to load directory: $e');
          }
        }
      }
    } else {
      _handleFileTap(node);
    }
  }

  Future<void> _pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        // Project loading is now handled by ProjectService
        // This method should be overridden in subclasses if needed
        _showError('Project loading is handled by the main application');
      }
    } catch (e) {
      _showError('Error selecting directory: $e');
    }
  }

  Future<void> _refreshProjectTree() async {
    if (_projectRoot == null) return;

    try {
      // Reload the project tree recursively
      final result = await _projectRoot!.enumerateContentsRecursive();

      if (result == LoadChildrenResult.success && mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to refresh project tree: $e');
    }
  }

  Future<void> _renameFile(ProjectNode node) async {
    final TextEditingController controller = TextEditingController(
      text: node.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            hintText: 'Enter new file name',
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

      // Check if target file already exists
      if (File(newPath).existsSync() || Directory(newPath).existsSync()) {
        _showError('A file or folder with this name already exists');
        return;
      }

      // Perform the rename operation
      if (node.isDirectory) {
        await Directory(node.path).rename(newPath);
      } else {
        await File(node.path).rename(newPath);
      }

      // Update the project tree
      await _refreshProjectTree();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$result"')));
      }
    } catch (e) {
      _showError('Failed to rename file: $e');
    }
  }

  Future<void> _revealInFileExplorer(ProjectNode node) async {
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
      } else {
        _showError('Reveal in file explorer is not supported on this platform');
      }
    } catch (e) {
      _showError('Failed to open file explorer: $e');
    }
  }

  Future<void> _seedGitStatusForFile(ProjectNode node) async {
    if (_projectRoot == null || !mounted) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(_projectRoot!.path);
      if (!isGitRepo) return;

      // Get Git status for this specific file
      final gitStatus = await _gitService.getStatus(_projectRoot!.path);
      final relativePath = path.relative(node.path, from: _projectRoot!.path);

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

  void _showError(String message) {
    if (mounted) {
      MessageHelper.showError(context, message, showCopyButton: true);
    }
  }

  void _showFileContextMenu(ProjectNode node, Offset position) {
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
      _handleFileContextMenuAction(value, node);
    });
  }

  void _showNodeContextMenu(ProjectNode node, Offset position) {
    debugPrint(
      '🎛️ BasePanel: Showing context menu for ${node.name} at $position',
    );
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
      debugPrint('🎯 BasePanel: Context menu selected: $value');
      _handleContextMenuAction(value, node);
    });
  }
}
