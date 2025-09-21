// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/message_helper.dart';

import 'shared_panel_utils.dart';
import '../../providers/app_providers.dart';
import '../../widgets/filename_widget.dart';

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

    // Group files and directories by categories
    final Map<String, List<ProjectNode>> categories = {
      'Root': [],
      'Lib': [],
      'Tests': [],
      'Assets': [],
      'Platforms': [],
      'Output': [],
    };

    // Find lib, test, and assets directories
    ProjectNode? libDir;
    ProjectNode? testDir;
    ProjectNode? assetsDir;

    for (final node in projectRoot!.children) {
      if (node.name == 'lib' && node.isDirectory) {
        libDir = node;
      } else if (node.name == 'test' && node.isDirectory) {
        testDir = node;
      } else if (node.name == 'assets' && node.isDirectory) {
        assetsDir = node;
      }
    }

    // Ensure lib directory contents are loaded
    if (libDir != null) {
      ensureDirectoryLoaded(libDir);
      if (libDir.children.isNotEmpty) {
        categories['Lib']!.addAll(libDir.children);
      }
    }

    // Ensure test directory contents are loaded
    if (testDir != null) {
      ensureDirectoryLoaded(testDir);
      if (testDir.children.isNotEmpty) {
        categories['Tests']!.addAll(testDir.children);
      }
    }

    // Ensure assets directory contents are loaded
    if (assetsDir != null) {
      ensureDirectoryLoaded(assetsDir);
      if (assetsDir.children.isNotEmpty) {
        categories['Assets']!.addAll(assetsDir.children);
      }
    }

    // Categorize remaining nodes
    for (final node in projectRoot!.children) {
      if (node == libDir || node == testDir || node == assetsDir) {
        // Skip lib, test, and assets directories as we already processed their contents
        continue;
      }

      if (node.name == 'android' ||
          node.name == 'ios' ||
          node.name == 'web' ||
          node.name == 'windows' ||
          node.name == 'macos' ||
          node.name == 'linux') {
        categories['Platforms']!.add(node);
      } else if (node.name == 'build' ||
          node.name == '.dart_tool' ||
          node.name == 'benchmark') {
        categories['Output']!.add(node);
      } else {
        categories['Root']!.add(node);
      }
    }

    // Deduplicate categories
    for (final category in categories.keys) {
      final uniqueNodes = <String, ProjectNode>{};
      for (final node in categories[category]!) {
        uniqueNodes[node.path] = node;
      }
      categories[category] = uniqueNodes.values.toList();
    }

    // Build the organized view
    final List<Widget> sections = [];

    for (final category in [
      'Root',
      'Lib',
      'Tests',
      'Assets',
      'Platforms',
      'Output',
    ]) {
      final nodes = categories[category]!;
      if (nodes.isNotEmpty) {
        sections.add(_buildCategorySection(category, nodes));
      }
    }

    return SingleChildScrollView(child: Column(children: sections));
  }

  Widget _buildCategorySection(String category, List<ProjectNode> nodes) {
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
                  category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${nodes.length})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Category content
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
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
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    // Copy Git status from ProjectNode to FileSystemItem
    item.gitStatus = node.gitStatus;
    // Set expansion state
    item.isExpanded = expandedState[node.path] ?? false;

    final isSelected = widget.selectedFile?.path == item.path;

    if (node.isDirectory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FileSystemItemWidget(
            item: item,
            isSelected: isSelected,
            showExpansionIndicator: true,
            showContextMenuButton: isSelected,
            onTap: () => _onNodeTapped(node, item.isExpanded),
            onLongPress: () => _showNodeContextMenu(node, const Offset(0, 0)),
            onContextMenuTap: (position) =>
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
      return FileSystemItemWidget(
        item: item,
        isSelected: isSelected,
        showExpansionIndicator: false,
        showContextMenuButton: isSelected,
        onTap: () => _handleFileTap(node),
        onLongPress: () => _showNodeContextMenu(node, const Offset(0, 0)),
        onContextMenuTap: (position) => _showNodeContextMenu(node, position),
      );
    }
  }
}
