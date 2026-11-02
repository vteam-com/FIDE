// ignore_for_file:  avoid_print

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
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
  /// The file last revealed through [explorerRevealPathProvider],
  /// highlighted until another file is selected.
  String? _revealedPath;

  /// Marks the row of [_revealedPath], to scroll it into view.
  final GlobalKey _revealedKey = GlobalKey();

  /// Where a revealed row is scrolled to: the middle of the tree.
  static const double _revealAlignment = 0.5;

  @override
  void didUpdateWidget(FolderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedFile?.path;
    if (oldWidget.selectedFile?.path != selected) {
      _revealedPath = null;
      if (selected != null) _expandTo(selected);
    }
  }

  /// Expands the folders down to the file at [path], loading them as
  /// needed; nothing for a file outside the project.
  Future<void> _expandTo(String path) async {
    final root = projectRoot;
    if (root == null || !p.isWithin(root.path, path)) return;
    var folder = root;
    for (final segment in p.split(
      p.relative(p.dirname(path), from: root.path),
    )) {
      if (segment == '.') break;
      final child = folder.children
          .where((node) => node.isDirectory && node.name == segment)
          .firstOrNull;
      if (child == null) break;
      await panelState.ensureDirectoryLoaded(child);
      expandedState[child.path] = true;
      folder = child;
    }
    if (mounted) setState(() {});
  }

  /// Clears the filter, expands the folders down to the file at [path],
  /// then highlights its row and scrolls to it.
  Future<void> _reveal(String path) async {
    ref.read(explorerRevealPathProvider.notifier).state = null;
    filterController.clear();
    await _expandTo(path);
    if (!mounted) return;
    setState(() => _revealedPath = path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _revealedKey.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: _revealAlignment,
          duration: AppDuration.editorScroll,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _expandToSelectedAfterBuild();
  }

  @override
  void onProjectTreeChanged() {
    _expandToSelectedAfterBuild();
  }

  /// Once the current build is done, expands the folders down to the
  /// selected file, so it shows when the panel or its tree is new.
  void _expandToSelectedAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = widget.selectedFile?.path;
      if (mounted && selected != null) _expandTo(selected);
    });
  }

  /// Returns `filterController`.
  TextEditingController get filterController => panelState.filterController;

  /// Returns `filterQuery`.
  String get filterQuery => panelState.filterQuery;

  void _handleFileSelection(ProjectNode node) {
    // Only select files for editing, not folders
    if (widget.onFileSelected != null && node.isFile) {
      widget.onFileSelected!(FileSystemItem.fromNode(node));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);
    // Rebuild when the tree changes in place, e.g. Git status arriving
    ref.watch(projectTreeRevisionProvider);

    syncProjectRoot(currentProjectRoot);

    // A file to reveal, asked for while this tab was hidden or just now
    if (ref.watch(explorerRevealPathProvider) case final path?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Several builds may schedule it; the first one handles it
        if (mounted && ref.read(explorerRevealPathProvider) == path) {
          _reveal(path);
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
      revealedPath: _revealedPath,
      revealedKey: _revealedKey,
      expandedState: panelState.expandedState,
      rootPath: projectRoot!.path,
      onNodeTapped: toggleOrOpenNode,
      onShowContextMenu: showNodeContextMenu,
      onFileSelected: _handleFileSelection,
    );
  }

  // File operations implementation
}
