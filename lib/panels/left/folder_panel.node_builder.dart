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
    this.onShowFileContextMenu,
    this.onFileSelected,
    this.isFilteredView = false,
  });

  final Map<String, bool> expandedState;
  final bool isFilteredView;
  final ProjectNode node;
  final Function(ProjectNode)? onFileSelected;
  final Function(ProjectNode, bool) onNodeTapped;
  final Function(ProjectNode, Offset) onShowContextMenu;
  final Function(ProjectNode, Offset)? onShowFileContextMenu;
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
    final hasError =
        node.loadResult != null &&
        node.loadResult != LoadChildrenResult.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FolderNameWidget(
          node: node,
          onTap: () => onNodeTapped(node, isExpanded),
          isExpanded: isExpanded && !hasError,
          rootPath: rootPath,
          onShowContextMenu: (offset) => onShowContextMenu(node, offset),
          hasError:
              node.loadResult != null &&
              node.loadResult != LoadChildrenResult.success,
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
                : _buildNodeChildren(),
          ),
      ],
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

  /// Handles `_buildNodeChildren`.
  Widget _buildNodeChildren() {
    final uniqueChildren = <String, ProjectNode>{};
    for (final child in node.children) {
      uniqueChildren[child.path] = child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: uniqueChildren.values
          .map(
            (child) => NodeBuilder(
              node: child,
              selectedFile: selectedFile,
              expandedState: expandedState,
              rootPath: rootPath,
              onNodeTapped: onNodeTapped,
              onShowContextMenu: onShowContextMenu,
              onShowFileContextMenu: onShowFileContextMenu,
              onFileSelected: onFileSelected,
              isFilteredView: isFilteredView,
            ),
          )
          .toList(),
    );
  }

  void _handleFileTap() {
    if (onFileSelected != null) {
      onFileSelected!(node);
    }
  }
}
