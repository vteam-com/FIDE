part of 'folder_panel.dart';

/// Shared node builder widget.
class NodeBuilder extends StatelessWidget {
  const NodeBuilder({
    super.key,
    required this.node,
    this.selectedFile,
    required this.expandedState,
    this.rootPath,
    required this.onNodeTapped,
    required this.onShowContextMenu,
    this.onFileSelected,
    this.isFilteredView = false,
  });

  final Map<String, bool> expandedState;
  final bool isFilteredView;
  final ProjectNode node;
  final Function(ProjectNode)? onFileSelected;
  final Function(ProjectNode, bool) onNodeTapped;
  final Function(ProjectNode, Offset) onShowContextMenu;
  final String? rootPath;
  final FileSystemItem? selectedFile;

  @override
  Widget build(BuildContext context) {
    if (node.isDirectory) {
      return _buildDirectoryNode();
    }
    return _buildFileNode();
  }

  /// Handles `_buildDirectoryNode`.
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

  /// Handles `_buildFileNode`.
  Widget _buildFileNode() {
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    item.gitStatus = node.gitStatus;

    final isSelected =
        selectedFile != null &&
        (selectedFile!.path == node.path ||
            path.normalize(selectedFile!.path) == path.normalize(node.path) ||
            path.canonicalize(selectedFile!.path) ==
                path.canonicalize(node.path));

    return FileNameWidget(
      fileItem: item,
      isSelected: isSelected,
      rootPath: rootPath,
      onTap: _handleFileTap,
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
            expandedState: expandedState,
            rootPath: rootPath,
            onNodeTapped: onNodeTapped,
            onShowContextMenu: onShowContextMenu,
            onFileSelected: onFileSelected,
            isFilteredView: isFilteredView,
          ),
        )
        .toList();
  }

  void _handleFileTap() {
    if (onFileSelected != null) {
      onFileSelected!(node);
    }
  }
}
