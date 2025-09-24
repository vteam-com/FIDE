// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/message_helper.dart';

import 'shared_panel_utils.dart';
import '../../providers/app_providers.dart';
import '../../widgets/filename_widget.dart';
import '../../widgets/foldername_widget.dart';

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
        });
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

    // Define concept-based categories
    final Map<String, List<String>> categoryDirs = {
      'Screens': ['lib/screens'],
      'Widgets': ['lib/widgets'],
      'Dialogs': ['lib/dialogs'],
      'Models': ['lib/models'],
      'Services': ['lib/services'],
      'Controllers': ['lib/providers'],
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
          categoryNodes['Screens']!.add(fileNode);
          categorizedFiles.add(fileNode.path);
        } else if (_isWidgetClass(content)) {
          categoryNodes['Widgets']!.add(fileNode);
          categorizedFiles.add(fileNode.path);
        }
      } catch (e) {
        // ignore
      }
    }

    // Move files containing 'showDialog' to Dialogs category, except for Screens/Pages
    for (final category in categoryNodes.keys.toList()) {
      if (category == 'Dialogs' || category == 'Screens') continue;
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

    // Mark files in Screens that have showDialog
    for (final node in categoryNodes['Screens']!) {
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

    // Build the organized view
    final List<Widget> sections = [];

    for (final category in categoryDirs.keys) {
      final nodes = categoryNodes[category]!;
      if (nodes.isNotEmpty) {
        final fileCount = _countFiles(nodes);
        final elementCount = _countElements(nodes, category);
        sections.add(
          _buildCategorySection(category, nodes, fileCount, elementCount),
        );
      }
    }

    return SingleChildScrollView(child: Column(children: sections));
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
    int count = 0;
    for (final node in nodes) {
      if (node.isDirectory) {
        count += _countElements(node.children, category);
      } else if (node.path.endsWith('.dart')) {
        try {
          final file = File(node.path);
          final content = file.readAsStringSync();
          if (category == 'Widgets' ||
              category == 'Screens' ||
              category == 'Dialogs') {
            // Count classes that extend something ending with Widget and class name not ending with State
            final classDeclarations = RegExp(
              r'class\s+(\w+)\s+extends\s+(\w+)',
              multiLine: true,
            ).allMatches(content);
            for (final match in classDeclarations) {
              final className = match.group(1)!;
              final baseClass = match.group(2)!;
              if (baseClass.endsWith('Widget') &&
                  !className.endsWith('State')) {
                count++;
              }
            }
          } else if (category == 'Models' || category == 'Services') {
            // Count all classes
            final classMatches = RegExp(
              r'^class\s+\w+',
              multiLine: true,
            ).allMatches(content);
            count += classMatches.length;
          } else {
            // Count classes and functions
            final classMatches = RegExp(
              r'^class\s+\w+',
              multiLine: true,
            ).allMatches(content);
            count += classMatches.length;
            final functionMatches = RegExp(
              r'^\s*(?:static\s+)?(?:\w+\s+)?\w+\s*\([^)]*\)\s*\{',
              multiLine: true,
            ).allMatches(content);
            count += functionMatches.length;
          }
        } catch (e) {
          // ignore
        }
      } else if (node.path.endsWith('.arb') && category == 'Localization') {
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
                Chip(
                  label: Text('$elementCount', style: TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
              children: nodes.map((node) => _buildNode(node)).toList(),
            ),
          ),
      ],
    );
  }

  // Helper method to build node widget
  Widget _buildNode(ProjectNode node) {
    FileSystemItem item = FileSystemItem.fromFileSystemEntity(File(node.path));
    // Copy Git status from ProjectNode to FileSystemItem
    item.gitStatus = node.gitStatus;
    // Set expansion state
    item.isExpanded = expandedState[node.path] ?? false;
    // Set warning if applicable
    if (_currentCategory == 'Screens' &&
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
