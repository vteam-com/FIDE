// ignore_for_file:  avoid_print

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/foldername_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

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
    final fileDir = path.dirname(filePath);
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
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
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
      textColor = Theme.of(context).colorScheme.onSurface
          .withValues(alpha: AppOpacity.disabled);
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    // Determine icon color
    Color iconColor;
    if (hasError) {
      iconColor = Theme.of(context).colorScheme.error;
    } else if (node.isHidden) {
      iconColor = Theme.of(context).colorScheme.primary
          .withValues(alpha: AppOpacity.disabled);
    } else {
      iconColor = Theme.of(context).colorScheme.primary;
    }

    // Highlight directory if it matches the filter
    final isMatching = panelState.matchesFilter(node);
    if (isMatching) {
      textColor = Theme.of(context).colorScheme.primary;
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => toggleOrOpenNode(node, isExpanded),
          onLongPressStart: (details) =>
              /// Handles `showNodeContextMenu`.
              showNodeContextMenu(node, details.globalPosition),
          child: Container(
            color: isMatching
                ? Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: AppOpacity.subtle)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: node.uniqueChildren
          .where(
            (child) =>
                panelState.hasMatchingDescendant(child) ||
                panelState.matchesFilter(child),
          )
          .map((child) => _buildFilteredNode(child))
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
