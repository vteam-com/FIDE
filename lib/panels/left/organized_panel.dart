import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_categories.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/empty_folder_label.dart';
import 'package:fide/widgets/foldername_widget.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// OrganizedPanel provides a categorized view of the project
class OrganizedPanel extends ProjectTreePanel {
  const OrganizedPanel({
    super.key,
    super.onFileSelected,
    super.selectedFile,
    super.initialProjectPath,
  });

  @override
  ConsumerState<OrganizedPanel> createState() => _OrganizedPanelState();
}

class _OrganizedPanelState extends ConsumerState<OrganizedPanel>
    with ProjectTreePanelState<OrganizedPanel> {
  final Map<String, FileSystemItem> _cachedFileSystemItems = {};

  /// The grouping of the current tree; null while it is computed.
  ProjectCategories? _categories;

  /// Bumped per categorization so a stale result is dropped.
  int _categorizeGeneration = 0;

  @override
  void onProjectTreeChanged() {
    _cachedFileSystemItems.clear();
    _categories = null;
    _categorize();
  }

  /// Groups the current tree off the build path and rebuilds with it.
  Future<void> _categorize() async {
    final root = projectRoot;
    if (root == null) return;
    final generation = ++_categorizeGeneration;
    final categories = await ref
        .read(projectCategorizerProvider)
        .categorize(root);
    if (!mounted || generation != _categorizeGeneration) return;
    setState(() => _categories = categories);
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);

    syncProjectRoot(currentProjectRoot);

    return !isProjectLoaded ? buildNotLoadedView() : buildPanelContent();
  }

  /// Handles `_OrganizedPanelState.buildPanelContent`.
  Widget buildPanelContent() {
    if (projectRoot == null) {
      return buildNoProjectView();
    }

    /// Handles `_buildOrganizedView`.
    return _buildOrganizedView();
  }

  /// One section per non-empty category, or a spinner while grouping.
  Widget _buildOrganizedView() {
    final categories = _categories;
    if (categories == null) {
      return const Center(child: InlineSpinner());
    }

    final sections = [
      for (final MapEntry(key: category, value: nodes)
          in categories.nodes.entries)
        if (nodes.isNotEmpty)
          _buildCategorySection(
            category,
            nodes,
            nodes.fold(0, (count, node) => count + _countFiles(node)),
            categories.elementCounts[category] ?? 0,
          ),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final isConstrained = constraints.maxHeight.isFinite;

        if (isConstrained) {
          return SingleChildScrollView(child: Column(children: sections));
        }

        // For unconstrained layouts, use a Container with fixed height (no flex)
        return SizedBox(
          height: AppSize.panelFallbackHeight,
          child: SingleChildScrollView(child: Column(children: sections)),
        );
      },
    );
  }

  /// Number of files in [node]'s loaded subtree (1 for a file).
  int _countFiles(ProjectNode node) {
    if (!node.isDirectory) return 1;
    return node.children.fold(0, (count, child) => count + _countFiles(child));
  }

  /// Handles `_buildCategorySection`.
  Widget _buildCategorySection(
    CodeCategory category,
    List<ProjectNode> nodes,
    int fileCount,
    int elementCount,
  ) {
    final expansionKey = 'category_${category.name}';
    final isExpanded = expandedState[expansionKey] ?? false;

    // Build the right widget with file count and element counter
    final rightWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.description,
          size: AppIconSize.small,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.micro),
        Text(
          '$fileCount',
          style: TextStyle(
            fontSize: AppFontSize.metadata,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final node in nodes) _buildNode(node, category)],
    );

    return SectionPanel(
      title: category.label,
      isExpanded: isExpanded,
      rightWidget: rightWidget,
      count: elementCount,
      child: contentWidget,
      onExpansionToggle: () {
        if (mounted) {
          setState(() {
            expandedState[expansionKey] = !isExpanded;
          });
        }
      },
    );
  }

  /// The row for [node] (and its expanded children) in [category].
  Widget _buildNode(ProjectNode node, CodeCategory category) {
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
    if (category == CodeCategory.views &&
        (_categories?.viewsWithDialogs.contains(node.path) ?? false)) {
      item = FileSystemItem(
        name: item.name,
        path: item.path,
        type: item.type,
        modified: item.modified,
        size: item.size,
        children: item.children,
        isExpanded: item.isExpanded,
        gitStatus: item.gitStatus,
        warning: 'This file contains a showDialog, we suggest to move dialog related code to single file with dialog logic.',
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
            onTap: () => toggleOrOpenNode(node, item.isExpanded),
            onShowContextMenu: (position) =>
                showNodeContextMenu(node, position),
          ),
          if (item.isExpanded)
            Padding(
              padding: AppPadding.nestedFolder,
              child: node.children.isEmpty
                  ? const EmptyFolderLabel()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final child in node.children)
                          _buildNode(child, category),
                      ],
                    ),
            ),
        ],
      );
    } else {
      return FileNameWidget(
        fileItem: item,
        isSelected: isSelected,
        rootPath: projectRoot!.path,
        onTap: () => handleFileTap(node),
        onContextMenu: (position) => showNodeContextMenu(node, position),
      );
    }
  }
}
