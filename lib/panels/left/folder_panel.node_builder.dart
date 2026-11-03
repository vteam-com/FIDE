part of 'folder_panel.dart';

/// A row of the Explorer's tree: a directory with its children when
/// expanded, or a file, highlighted when selected or revealed.
class NodeBuilder extends StatelessWidget {
  /// Creates the row of [node].
  const NodeBuilder({
    super.key,
    required this.node,
    this.selectedFile,
    this.revealedPath,
    this.revealedKey,
    required this.expandedState,
    this.rootPath,
    required this.onNodeTapped,
    required this.onShowContextMenu,
  });

  /// Expanded/collapsed state by directory path.
  final Map<String, bool> expandedState;

  /// The node shown.
  final ProjectNode node;

  /// Called with the node tapped and whether it is expanded: toggles a
  /// directory, opens a file.
  final Function(ProjectNode, bool) onNodeTapped;

  /// Shows the node's context menu at the given position.
  final Function(ProjectNode, Offset) onShowContextMenu;

  /// Key given to the row of [revealedPath], to scroll it into view.
  final GlobalKey? revealedKey;

  /// A file revealed in the tree, highlighted like [selectedFile].
  final String? revealedPath;

  /// The project folder paths are shown relative to.
  final String? rootPath;

  /// The file open in the editor, highlighted.
  final FileSystemItem? selectedFile;

  @override
  Widget build(BuildContext context) {
    if (node.isDirectory) {
      return _buildDirectoryNode();
    }
    return _buildFileNode();
  }

  /// The directory row with, when expanded, one [NodeBuilder] per child.
  Widget _buildDirectoryNode() {
    final isExpanded = expandedState[node.path] ?? false;
    return FolderNode(
      node: node,
      isExpanded: isExpanded,
      rootPath: rootPath,
      onTap: () => onNodeTapped(node, isExpanded),
      onShowContextMenu: (offset) => onShowContextMenu(node, offset),
      // Only built when open: a collapsed folder skips its whole subtree
      children: isExpanded ? _buildNodeChildren() : const [],
    );
  }

  /// The file row, highlighted when selected or revealed.
  Widget _buildFileNode() {
    final isRevealed = node.path == revealedPath;
    final isSelected =
        isRevealed ||
        selectedFile != null &&
            (selectedFile!.path == node.path ||
                p.normalize(selectedFile!.path) == p.normalize(node.path) ||
                p.canonicalize(selectedFile!.path) ==
                    p.canonicalize(node.path));

    return FileNameWidget(
      key: isRevealed ? revealedKey : null,
      fileItem: FileSystemItem.fromNode(node),
      isSelected: isSelected,
      rootPath: rootPath,
      onTap: () => onNodeTapped(node, false),
      onContextMenu: (offset) => onShowContextMenu(node, offset),
    );
  }

  /// One [NodeBuilder] per child, sharing this node's settings.
  List<Widget> _buildNodeChildren() {
    return node.uniqueChildren
        .map(
          (child) => NodeBuilder(
            node: child,
            selectedFile: selectedFile,
            revealedPath: revealedPath,
            revealedKey: revealedKey,
            expandedState: expandedState,
            rootPath: rootPath,
            onNodeTapped: onNodeTapped,
            onShowContextMenu: onShowContextMenu,
          ),
        )
        .toList();
  }
}
