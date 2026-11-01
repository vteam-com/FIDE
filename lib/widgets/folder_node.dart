import 'package:fide/models/project_node.dart';
import 'package:fide/widgets/foldername_widget.dart';
import 'package:fide/widgets/tree_branch.dart';
import 'package:flutter/material.dart';

/// A directory in a project tree: its name row and, when expanded, its
/// indented [children], or an empty-folder label when the directory has
/// no entries.
///
/// A folder whose children failed to load never shows as expanded.
class FolderNode extends StatelessWidget {
  /// Creates the tree entry for directory [node].
  const FolderNode({
    super.key,
    required this.node,
    required this.isExpanded,
    required this.rootPath,
    required this.children,
    required this.onTap,
    required this.onShowContextMenu,
    this.isFiltered = false,
    this.trailing,
  });

  /// Entries shown under the folder when it is expanded.
  final List<Widget> children;

  /// Whether the folder is open.
  final bool isExpanded;

  /// Whether the folder's own name matches the active filter.
  final bool isFiltered;

  /// The directory shown.
  final ProjectNode node;

  /// Opens the folder's context menu at a global position.
  final ValueChanged<Offset> onShowContextMenu;

  /// Toggles the folder open or closed.
  final VoidCallback onTap;

  /// Project root, for paths shown relative to it.
  final String? rootPath;

  /// Shown after the name, e.g. a warning.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasError = node.hasLoadError;
    return TreeBranch(
      header: FolderNameWidget(
        node: node,
        isExpanded: isExpanded && !hasError,
        isFiltered: isFiltered,
        hasError: hasError,
        rootPath: rootPath,
        trailing: trailing,
        onTap: onTap,
        onShowContextMenu: onShowContextMenu,
      ),
      isExpanded: isExpanded,
      isEmpty: node.children.isEmpty,
      children: children,
    );
  }
}
