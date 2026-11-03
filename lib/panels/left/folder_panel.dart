import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/panels/left/tree_filter.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/folder_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

part 'folder_panel.node_builder.dart';

/// The Explorer tab: the project's folders and files as they are on disk,
/// filtered by name from the field at the bottom.
class FolderPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const FolderPanel({super.key});

  @override
  ConsumerState<FolderPanel> createState() => _FolderPanelState();
}

class _FolderPanelState extends ConsumerState<FolderPanel>
    with ProjectTreePanelState<FolderPanel> {
  /// The name filter under the tree.
  late final TreeFilter _filter = TreeFilter(onChanged: _onFilterChanged);

  /// The file last revealed through [explorerRevealPathProvider],
  /// highlighted until another file is selected.
  String? _revealedPath;

  /// Marks the row of [_revealedPath], to scroll it into view.
  final GlobalKey _revealedKey = GlobalKey();

  /// Where a revealed row is scrolled to: the middle of the tree.
  static const double _revealAlignment = 0.5;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  /// Starts the tree over when the filter changes, expanding the folders
  /// that hold a match.
  void _onFilterChanged() {
    expandedState.clear();
    if (projectRoot case final root?) {
      for (final path in _filter.foldersToExpand(root)) {
        expandedState[path] = true;
      }
    }
    setState(() {});
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
      await ensureDirectoryLoaded(child);
      expandedState[child.path] = true;
      folder = child;
    }
    if (mounted) setState(() {});
  }

  /// Clears the filter, expands the folders down to the file at [path],
  /// then highlights its row and scrolls to it.
  Future<void> _reveal(String path) async {
    ref.read(explorerRevealPathProvider.notifier).state = null;
    _filter.clear();
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
      final selected = ref.read(selectedFileProvider)?.path;
      if (mounted && selected != null) _expandTo(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Follow the selected file: another file drops the revealed one
    ref.listen<FileSystemItem?>(selectedFileProvider, (previous, next) {
      final selected = next?.path;
      if (previous?.path != selected) {
        _revealedPath = null;
        if (selected != null) _expandTo(selected);
      }
    });

    // A file to reveal, asked for while this tab was hidden or just now
    if (ref.watch(explorerRevealPathProvider) case final path?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Several builds may schedule it; the first one handles it
        if (mounted && ref.read(explorerRevealPathProvider) == path) {
          _reveal(path);
        }
      });
    }

    return buildPanelContent();
  }

  @override
  Widget buildProjectTree(ProjectNode root) {
    final selectedFile = ref.watch(selectedFileProvider);
    final tree = SingleChildScrollView(
      child: _filter.isActive
          ? _buildFilteredTree(root, selectedFile)
          : Column(
              children: [
                for (final node in root.children)
                  _buildNode(node, root, selectedFile),
              ],
            ),
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
            FilterField(controller: _filter.controller),
          ],
        );
      },
    );
  }

  /// The nodes of [root] holding a match, keeping the directory structure.
  Widget _buildFilteredTree(ProjectNode root, FileSystemItem? selectedFile) {
    return Column(
      children: [
        for (final node in root.children)
          if (_filter.hasMatchingDescendant(node))
            _buildFilteredNode(node, root, selectedFile),
      ],
    );
  }

  /// A row of the filtered tree: a directory with its matching children,
  /// or a file.
  Widget _buildFilteredNode(
    ProjectNode node,
    ProjectNode root,
    FileSystemItem? selectedFile,
  ) {
    if (!node.isDirectory) return _buildNode(node, root, selectedFile);
    // Highlighted when its own name matches; starts expanded
    final isExpanded = expandedState[node.path] ?? true;
    return FolderNode(
      node: node,
      isExpanded: isExpanded,
      isFiltered: _filter.matches(node),
      rootPath: root.path,
      onTap: () => toggleOrOpenNode(node, isExpanded),
      onShowContextMenu: (position) => showNodeContextMenu(node, position),
      children: [
        for (final child in node.uniqueChildren)
          if (_filter.hasMatchingDescendant(child))
            _buildFilteredNode(child, root, selectedFile),
      ],
    );
  }

  /// The row of [node] under [root] and, when expanded, its children.
  Widget _buildNode(
    ProjectNode node,
    ProjectNode root,
    FileSystemItem? selectedFile,
  ) {
    return NodeBuilder(
      node: node,
      selectedFile: selectedFile,
      revealedPath: _revealedPath,
      revealedKey: _revealedKey,
      expandedState: expandedState,
      rootPath: root.path,
      onNodeTapped: toggleOrOpenNode,
      onShowContextMenu: showNodeContextMenu,
    );
  }
}
