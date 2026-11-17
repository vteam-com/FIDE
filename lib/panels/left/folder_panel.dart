import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/panels/left/tree_filter.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/filename_widget.dart';
import 'package:fide/widget_services/selected_file_builder.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/folder_node.dart';
import 'package:fide/widgets/tree_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
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

  /// Jumps toward a revealed row not built yet before giving up.
  static const int _revealAttempts = 3;

  /// Scrolls the tree, to reveal a row.
  final ScrollController _scrollController = ScrollController();

  /// The tree's shown rows, as of the last build.
  List<TreeListRow<ProjectNode>> _rows = const [];

  @override
  void dispose() {
    _filter.dispose();
    _scrollController.dispose();
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
    _scrollToRevealed(_revealAttempts);
  }

  /// Once the current frame is laid out, scrolls the revealed row into
  /// view. The tree builds only the rows on screen, so a row far off it is
  /// first jumped near, up to [attemptsLeft] times, until it is built.
  void _scrollToRevealed(int attemptsLeft) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _revealedKey.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: _revealAlignment,
          duration: AppDuration.editorScroll,
        );
        return;
      }
      final index = _rows.indexWhere((row) => row.node.path == _revealedPath);
      if (index < 0 || attemptsLeft == 0 || !_scrollController.hasClients) {
        return;
      }
      // Rows are about one height: the row sits at its share of the list
      final position = _scrollController.position;
      final extent = position.maxScrollExtent + position.viewportDimension;
      position.jumpTo(
        (extent * index / _rows.length).clamp(0, position.maxScrollExtent),
      );
      _scrollToRevealed(attemptsLeft - 1);
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
        setState(() => _revealedPath = null);
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
    // Filtered, the tree keeps the matches and the folders holding them,
    // found in one pass, with those folders open at first
    final kept = _filter.isActive ? _filter.keptPaths(root) : null;
    Iterable<ProjectNode> shown(Iterable<ProjectNode> nodes) =>
        kept == null ? nodes : nodes.where((node) => kept.contains(node.path));
    bool isExpanded(ProjectNode node) =>
        expandedState[node.path] ?? kept != null;
    final rows = _rows = TreeListView.flatten(
      shown(root.children),
      // A collapsed folder skips its whole subtree
      childrenOf: (node) => node.isDirectory && isExpanded(node)
          ? shown(node.uniqueChildren)
          : const [],
    );
    final tree = TreeListView(
      rows: rows,
      controller: _scrollController,
      rowBuilder: (_, node) => NodeBuilder(
        node: node,
        isExpanded: isExpanded(node),
        // A folder is highlighted when its own name matches
        isFiltered: kept != null && _filter.matches(node),
        revealedPath: _revealedPath,
        revealedKey: _revealedKey,
        rootPath: root.path,
        onNodeTapped: toggleOrOpenNode,
        onShowContextMenu: showNodeContextMenu,
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
}
