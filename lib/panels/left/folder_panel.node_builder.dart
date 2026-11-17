part of 'folder_panel.dart';

/// The row of one node of the Explorer's tree: a directory, whose children
/// have rows of their own, or a file, highlighted when selected or
/// revealed.
class NodeBuilder extends StatelessWidget {
  /// Creates the row of [node].
  const NodeBuilder({
    super.key,
    required this.node,
    required this.isExpanded,
    this.isFiltered = false,
    this.revealedPath,
    this.revealedKey,
    this.rootPath,
    required this.onNodeTapped,
    required this.onShowContextMenu,
  });

  /// Whether a directory [node] is open.
  final bool isExpanded;

  /// Whether a directory [node]'s own name matches the active filter.
  final bool isFiltered;

  /// The node shown.
  final ProjectNode node;

  /// Called with the node tapped and whether it is expanded: toggles a
  /// directory, opens a file.
  final Function(ProjectNode, bool) onNodeTapped;

  /// Shows the node's context menu at the given position.
  final Function(ProjectNode, Offset) onShowContextMenu;

  /// Key given to the row of [revealedPath], to scroll it into view.
  final GlobalKey? revealedKey;

  /// A file revealed in the tree, highlighted like the selected file.
  final String? revealedPath;

  /// The project folder paths are shown relative to.
  final String? rootPath;

  @override
  Widget build(BuildContext context) {
    if (node.isDirectory) {
      return FolderNode(
        node: node,
        isExpanded: isExpanded,
        isFiltered: isFiltered,
        rootPath: rootPath,
        onTap: () => onNodeTapped(node, isExpanded),
        onShowContextMenu: (offset) => onShowContextMenu(node, offset),
        // The children follow in rows of their own; an empty folder still
        // shows its label here
        children: const [],
      );
    }
    final isRevealed = node.path == revealedPath;
    return SelectedFileBuilder(
      path: node.path,
      builder: (_, isSelected) => FileNameWidget(
        key: isRevealed ? revealedKey : null,
        fileItem: FileSystemItem.fromNode(node),
        isSelected: isRevealed || isSelected,
        rootPath: rootPath,
        onTap: () => onNodeTapped(node, false),
        onContextMenu: (offset) => onShowContextMenu(node, offset),
      ),
    );
  }
}
