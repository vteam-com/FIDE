// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/message_helper.dart';

import 'shared_panel_utils.dart';
import '../../providers/app_providers.dart';
import '../../widgets/filename_widget.dart';
import '../../widgets/foldername_widget.dart';
import '../../widgets/container_counter.dart';

/// OrganizedPanel provides a categorized view of the project
class OrganizedPanel extends ConsumerStatefulWidget {
  const OrganizedPanel({
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
  ConsumerState<OrganizedPanel> createState() => OrganizedPanelState();
}

class OrganizedPanelState extends ConsumerState<OrganizedPanel> {
  final PanelStateManager _panelState = PanelStateManager();
  final Map<String, bool> _filesWithShowDialog = {};
  final Map<String, int> _cachedElementCounts = {};

  // Comprehensive caching for performance
  Map<String, List<ProjectNode>>? _cachedCategoryNodes;
  final Map<String, List<ProjectNode>> _cachedSortedNodes = {};
  final Map<String, FileSystemItem> _cachedFileSystemItems = {};
  bool _needsRecachery = true;
  String _currentCategory = '';

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
  ProjectNode? get projectRoot => _panelState.projectRoot;
  Map<String, bool> get expandedState => _panelState.expandedState;

  // Helper methods
  void showError(String message) {
    MessageHelper.showError(context, message, showCopyButton: true);
  }

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

  Future<void> ensureDirectoryLoaded(ProjectNode node) async {
    await _panelState.ensureDirectoryLoaded(node);
  }

  void _onNodeTapped(ProjectNode node, bool isExpanded) async {
    if (node.isDirectory) {
      if (mounted) {
        setState(() {
          _panelState.expandedState[node.path] = !isExpanded;
        });
      }

      if (!isExpanded && node.children.isEmpty) {
        try {
          await _panelState.ensureDirectoryLoaded(node);
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          showError('Failed to load directory: $e');
        }
      }
    } else {
      _handleFileTap(node);
    }
  }

  void _handleFileTap(ProjectNode node) {
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    if (widget.selectedFile?.path == item.path) return;

    // Seed Git status for the selected file if not already loaded
    if (node.gitStatus == GitFileStatus.clean &&
        _panelState.projectRoot != null) {
      _panelState.seedGitStatusForFile(node);
    }

    // Only trigger file selection if widget is still mounted
    if (widget.onFileSelected != null && mounted) {
      widget.onFileSelected!(item);
    }
  }

  void _showNodeContextMenu(ProjectNode node, Offset position) {
    ContextMenuHandler.showNodeContextMenu(
      context,
      node,
      position,
      _handleContextMenuAction,
    );
  }

  void _handleContextMenuAction(String action, ProjectNode node) {
    switch (action) {
      case 'open':
        _onNodeTapped(node, _panelState.expandedState[node.path] ?? false);
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
          final relative = p.relative(node.path, from: projectRoot!.path);
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

  Future<void> _refreshProjectTree() async {
    if (_panelState.projectRoot == null) return;

    try {
      // Reload the project tree recursively
      await _panelState.projectRoot!.enumerateContentsRecursive();

      // Invalidate caches when project tree changes
      _needsRecachery = true;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showError('Failed to refresh project tree: $e');
    }
  }

  // Method to build cached categorization - only rebuilds when needed
  Map<String, List<ProjectNode>> _getCategoryNodes() {
    if (!_needsRecachery && _cachedCategoryNodes != null) {
      return _cachedCategoryNodes!;
    }

    // Define concept-based categories
    final Map<String, List<String>> categoryDirs = {
      'Views': ['lib/views', 'lib/screens', 'lib/pages'],
      'Dialogs': ['lib/dialogs'],
      'Widgets': ['lib/widgets'],
      'Services': ['lib/services'],
      'Controllers': ['lib/providers', 'lib/controls'],
      'Models': ['lib/models', 'lib/data'],
      'Localization': ['lib/l10n', 'l10n'],
    };

    // Collect nodes for each category
    final Map<String, List<ProjectNode>> categoryNodes = {};
    for (final category in categoryDirs.keys) {
      categoryNodes[category] = [];
      for (final dirPath in categoryDirs[category]!) {
        final dirNode = _findDirectoryNode(projectRoot!, dirPath);
        if (dirNode != null) {
          ensureDirectoryLoaded(dirNode);
          categoryNodes[category]!.addAll(dirNode.children);
        }
      }
    }

    // Find unmatched Dart files and categorize based on content
    final Set<String> categorizedFiles = {};
    for (final nodes in categoryNodes.values) {
      _collectFilePaths(nodes, categorizedFiles);
    }

    // Only search for unmatched files within the lib directory
    final libDir = _findDirectoryNode(projectRoot!, 'lib');
    final unmatchedFiles = libDir != null
        ? _findUnmatchedDartFiles(libDir, categorizedFiles)
        : <ProjectNode>[];
    for (final fileNode in unmatchedFiles) {
      try {
        final content = File(fileNode.path).readAsStringSync();
        if (content.contains('MaterialApp(')) {
          categoryNodes['Views']!.add(fileNode);
          categorizedFiles.add(fileNode.path);
        } else if (_isWidgetClass(content)) {
          categoryNodes['Widgets']!.add(fileNode);
          categorizedFiles.add(fileNode.path);
        }
      } catch (e) {
        // ignore
      }
    }

    // Move files containing 'showDialog' to Dialogs category, except for Views/Pages
    for (final category in categoryNodes.keys.toList()) {
      if (category == 'Dialogs' || category == 'Views') continue;
      final filesToMove = <ProjectNode>[];
      for (final node in categoryNodes[category]!) {
        if (!node.isDirectory && node.path.endsWith('.dart')) {
          try {
            final content = File(node.path).readAsStringSync();
            if (content.contains('showDialog')) {
              _filesWithShowDialog[node.path] = true;
              filesToMove.add(node);
            }
          } catch (e) {
            // ignore
          }
        }
      }
      for (final node in filesToMove) {
        categoryNodes[category]!.remove(node);
        categoryNodes['Dialogs']!.add(node);
      }
    }

    // Mark files in Views that have showDialog
    for (final node in categoryNodes['Views']!) {
      if (!node.isDirectory && node.path.endsWith('.dart')) {
        try {
          final content = File(node.path).readAsStringSync();
          if (content.contains('showDialog')) {
            _filesWithShowDialog[node.path] = true;
          }
        } catch (e) {
          // ignore
        }
      }
    }

    // Cache the result
    _cachedCategoryNodes = categoryNodes;
    _needsRecachery = false;

    return categoryNodes;
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);

    // Update local state when project data changes
    if (currentProjectRoot != _panelState.projectRoot) {
      _panelState.projectRoot = currentProjectRoot;
      // Clear expanded state when project changes
      _panelState.expandedState.clear();
      // Clear caches when project changes
      _filesWithShowDialog.clear();
      _cachedElementCounts.clear();
      _cachedCategoryNodes = null;
      _cachedSortedNodes.clear();
      _cachedFileSystemItems.clear();
      _needsRecachery = true;

      if (mounted) {
        setState(() {});
      }
    }

    return !isProjectLoaded
        ? Container(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(
              child: Text('No project loaded', style: TextStyle(fontSize: 16)),
            ),
          )
        : buildPanelContent();
  }

  Widget buildPanelContent() {
    if (projectRoot == null) {
      return Container(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 48, color: Colors.grey),
              SizedBox(height: 16),
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

    return _buildOrganizedView();
  }

  Widget _buildOrganizedView() {
    if (projectRoot == null) return const SizedBox();

    // Get cached category nodes - only recomputes when filesystem changes
    final categoryNodes = _getCategoryNodes();

    // Build the organized view from cached data
    final List<Widget> sections = [];

    for (final category in categoryNodes.keys) {
      final nodes = categoryNodes[category]!;
      if (nodes.isNotEmpty) {
        final fileCount = _countFiles(nodes);
        final elementCount = _countElements(nodes, category);
        sections.add(
          _buildCategorySection(category, nodes, fileCount, elementCount),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isConstrained = constraints.maxHeight.isFinite;

        if (isConstrained) {
          return SingleChildScrollView(child: Column(children: sections));
        }

        // For unconstrained layouts, use a Container with fixed height (no flex)
        return SizedBox(
          height: 600, // Reasonable default height for unconstrained layouts
          child: SingleChildScrollView(child: Column(children: sections)),
        );
      },
    );
  }

  void _collectFilePaths(List<ProjectNode> nodes, Set<String> filePaths) {
    for (final node in nodes) {
      if (node.isDirectory) {
        _collectFilePaths(node.children, filePaths);
      } else {
        filePaths.add(node.path);
      }
    }
  }

  List<ProjectNode> _findUnmatchedDartFiles(
    ProjectNode root,
    Set<String> categorizedFiles,
  ) {
    final List<ProjectNode> unmatched = [];
    _findDartFilesRecursive(root, unmatched, categorizedFiles);
    return unmatched;
  }

  void _findDartFilesRecursive(
    ProjectNode node,
    List<ProjectNode> unmatched,
    Set<String> categorizedFiles,
  ) {
    if (node.isDirectory) {
      for (final child in node.children) {
        _findDartFilesRecursive(child, unmatched, categorizedFiles);
      }
    } else if (node.path.endsWith('.dart') &&
        !categorizedFiles.contains(node.path)) {
      unmatched.add(node);
    }
  }

  bool _isWidgetClass(String content) {
    final classDeclarations = RegExp(
      r'class\s+(\w+)\s+extends\s+(\w+)',
      multiLine: true,
    ).allMatches(content);
    for (final match in classDeclarations) {
      final baseClass = match.group(2)!;
      if (baseClass.endsWith('Widget')) {
        return true;
      }
    }
    return false;
  }

  ProjectNode? _findDirectoryNode(ProjectNode root, String path) {
    final parts = path.split('/');
    ProjectNode? current = root;
    for (final part in parts) {
      if (part.isEmpty) continue;
      final candidates = current?.children
          .where((child) => child.name == part && child.isDirectory)
          .toList();
      if (candidates != null && candidates.isNotEmpty) {
        current = candidates.first;
      } else {
        current = null;
      }
      if (current == null) return null;
    }
    return current;
  }

  int _countFiles(List<ProjectNode> nodes) {
    int count = 0;
    for (final node in nodes) {
      if (node.isDirectory) {
        count += _countFiles(node.children);
      } else {
        count++;
      }
    }
    return count;
  }

  int _countElements(List<ProjectNode> nodes, String category) {
    // Create a cache key based on category and nodes
    final cacheKey =
        '${category}_${nodes.length}_${nodes.map((n) => n.path).join('|').hashCode}';
    if (_cachedElementCounts.containsKey(cacheKey)) {
      return _cachedElementCounts[cacheKey]!;
    }

    int count = 0;
    for (final node in nodes) {
      if (node.isDirectory) {
        count += _countElements(node.children, category);
      } else if (node.path.endsWith('.dart')) {
        // Skip file reading for performance - just count files as 1
        // This is a performance optimization to avoid sync file reads during build
        if (category == 'Widgets' ||
            category == 'Views' ||
            category == 'Dialogs') {
          count += 1; // Assume 1 class per file as a rough estimate
        } else if (category == 'Models' || category == 'Services') {
          count += 1; // Assume 1 class per file as a rough estimate
        } else {
          count += 1; // Assume at least 1 element (class/function) per file
        }
      } else if (node.path.endsWith('.arb') && category == 'Localization') {
        // For ARB files, we can still read them since they're small
        try {
          final file = File(node.path);
          final content = file.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          // Count keys that don't start with @
          count += json.keys.where((key) => !key.startsWith('@')).length;
        } catch (e) {
          // ignore
        }
      }
    }

    // Cache the result
    _cachedElementCounts[cacheKey] = count;
    return count;
  }

  Widget _buildCategorySection(
    String category,
    List<ProjectNode> nodes,
    int fileCount,
    int elementCount,
  ) {
    _currentCategory = category;
    final isExpanded = expandedState['category_$category'] ?? false;

    // Cache sorted nodes to avoid re-sorting on every build
    final cacheKey =
        '${category}_${nodes.map((n) => n.path).join('|').hashCode}';
    List<ProjectNode> sortedNodes;

    if (_cachedSortedNodes.containsKey(cacheKey)) {
      sortedNodes = _cachedSortedNodes[cacheKey]!;
    } else {
      // Sort nodes: directories first, then files, both alphabetically ascending
      sortedNodes = List.from(nodes);
      sortedNodes.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _cachedSortedNodes[cacheKey] = sortedNodes;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        InkWell(
          onTap: () {
            if (mounted) {
              setState(() {
                expandedState['category_$category'] = !isExpanded;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: -1.0,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.description,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  '$fileCount',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                const ContainerCounter(
                  count: 0,
                ), // Disable for now to avoid rebuild overhead
              ],
            ),
          ),
        ),
        // Category content
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedNodes.map((node) => _buildNode(node)).toList(),
            ),
          ),
      ],
    );
  }

  // Helper method to build node widget
  Widget _buildNode(ProjectNode node) {
    // Cache FileSystemItem creation to avoid expensive object creation on every build
    final itemCacheKey = '${node.path}_${node.gitStatus.index}';
    FileSystemItem item;

    if (_cachedFileSystemItems.containsKey(itemCacheKey)) {
      // Use cached FileSystemItem and update dynamic properties
      item = _cachedFileSystemItems[itemCacheKey]!;
      item.isExpanded =
          expandedState[node.path] ?? false; // Update expansion state
    } else {
      // Create new FileSystemItem - expensive operation
      item = FileSystemItem.fromFileSystemEntity(File(node.path));
      item.gitStatus = node.gitStatus;
      item.isExpanded = expandedState[node.path] ?? false;

      // Cache it
      _cachedFileSystemItems[itemCacheKey] = item;
    }

    // Add warning if applicable - this creates a new object but warnings are rare
    if (_currentCategory == 'Views' &&
        _filesWithShowDialog[node.path] == true) {
      item = FileSystemItem(
        name: item.name,
        path: item.path,
        type: item.type,
        modified: item.modified,
        size: item.size,
        children: item.children,
        isExpanded: item.isExpanded,
        gitStatus: item.gitStatus,
        warning:
            'This file contains a showDialog, we suggest to move dialog related code to single file with dialog logic.',
      );
    }

    final isSelected = widget.selectedFile?.path == item.path;

    if (node.isDirectory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FolderNameWidget(
            node: node,
            isExpanded: item.isExpanded,
            rootPath: projectRoot!.path,
            onTap: () => _onNodeTapped(node, item.isExpanded),
            onShowContextMenu: (position) =>
                _showNodeContextMenu(node, position),
          ),
          if (item.isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: node.children.isEmpty
                  ? const Text(
                      'empty folder',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: node.children
                          .map((child) => _buildNode(child))
                          .toList(),
                    ),
            ),
        ],
      );
    } else {
      return FileNameWidget(
        fileItem: item,
        isSelected: isSelected,
        rootPath: projectRoot!.path,
        onTap: () => _handleFileTap(node),
        onContextMenu: (position) => _showNodeContextMenu(node, position),
      );
    }
  }
}
