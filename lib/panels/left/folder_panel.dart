// ignore_for_file:  avoid_print

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/folder_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

part 'folder_panel.node_builder.dart';

/// FolderPanel provides a filesystem-style view of the project
class FolderPanel extends ProjectTreePanel {
  const FolderPanel({
    super.key,
    super.onFileSelected,
    super.selectedFile,
    super.initialProjectPath,
  });

  @override
  ConsumerState<FolderPanel> createState() => _FolderPanelState();
}

class _FolderPanelState extends ConsumerState<FolderPanel>
    with ProjectTreePanelState<FolderPanel> {
  // Performance optimization caches
  final Map<String, FileSystemItem> _cachedFileSystemItems = {};

  @override
  void onProjectTreeChanged() {
    _cachedFileSystemItems.clear();
  }

  /// Returns `filterController`.
  TextEditingController get filterController => panelState.filterController;

  /// Returns `filterQuery`.
  String get filterQuery => panelState.filterQuery;

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
    if (panelState.projectRoot == null || !mounted) return;

    // For filesystem view, expand the directory containing the file
    final fileDir = p.dirname(filePath);
    if (fileDir != panelState.projectRoot!.path) {
      /// Handles `_findNodeByPath`.
      final directoryNode = _findNodeByPath(fileDir);
      if (directoryNode != null && mounted) {
        setState(() {
          panelState.expandedState[fileDir] = true;
        });
      }
    }
  }

  /// Handles `_findNodeByPath`.
  ProjectNode? _findNodeByPath(String targetPath) {
    if (panelState.projectRoot == null) return null;

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

    return findInNode(panelState.projectRoot!);
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);
    // Rebuild when the tree changes in place, e.g. Git status arriving
    ref.watch(projectTreeRevisionProvider);

    syncProjectRoot(currentProjectRoot);

    // Ensure selected file is expanded and visible when building
    if (widget.selectedFile != null && panelState.projectRoot != null) {
      // Use a microtask to ensure this happens after the current build cycle
      Future.microtask(() {
        if (mounted) {
          _ensureSelectedFileVisible(widget.selectedFile!.path);
        }
      });
    }

    return !isProjectLoaded ? buildNotLoadedView() : buildPanelContent();
  }

  /// Handles `_FolderPanelState.buildPanelContent`.
  Widget buildPanelContent() {
    if (projectRoot == null) {
      return buildNoProjectView();
    }

    final tree = SingleChildScrollView(
      child: filterQuery.isEmpty
          ? Column(
              children: [
                for (final node in projectRoot!.children) _buildNode(node),
              ],
            )
          : _buildFilteredTree(),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        return Column(
          children: [
            // Unbounded parents get a fixed-height tree instead of Expanded
            if (constraints.maxHeight.isFinite)
              Expanded(child: tree)
            else
              SizedBox(height: AppSize.folderPanelFallbackHeight, child: tree),
            FilterField(controller: filterController),
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
          .where(
            (node) =>
                panelState.hasMatchingDescendant(node) ||
                panelState.matchesFilter(node),
          )
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

  /// A directory row in the filtered tree, highlighted when its own name
  /// matches; filtered directories start expanded.
  Widget _buildFilteredDirectoryNode(ProjectNode node) {
    final isExpanded = expandedState[node.path] ?? true;
    return FolderNode(
      node: node,
      isExpanded: isExpanded,
      isFiltered: panelState.matchesFilter(node),
      rootPath: projectRoot!.path,
      onTap: () => toggleOrOpenNode(node, isExpanded),
      onShowContextMenu: (position) => showNodeContextMenu(node, position),
      children: node.uniqueChildren
          .where(
            (child) =>
                panelState.hasMatchingDescendant(child) ||
                panelState.matchesFilter(child),
          )
          .map(_buildFilteredNode)
          .toList(),
    );
  }

  // Helper method to build node widget
  Widget _buildNode(ProjectNode node) {
    return NodeBuilder(
      node: node,
      selectedFile: widget.selectedFile,
      expandedState: panelState.expandedState,
      rootPath: projectRoot!.path,
      onNodeTapped: toggleOrOpenNode,
      onShowContextMenu: showNodeContextMenu,
      onFileSelected: _handleFileSelection,
    );
  }

  // File operations implementation
}
