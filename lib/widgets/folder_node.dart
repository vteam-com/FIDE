import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/widgets/empty_folder_label.dart';
import 'package:fide/widgets/foldername_widget.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FolderNameWidget(
          node: node,
          isExpanded: isExpanded && !hasError,
          isFiltered: isFiltered,
          hasError: hasError,
          rootPath: rootPath,
          trailing: trailing,
          onTap: onTap,
          onShowContextMenu: onShowContextMenu,
        ),
        if (isExpanded)
          Padding(
            // The empty label lines up with the name, past the chevron
            padding: EdgeInsets.only(
              left: node.children.isEmpty
                  ? AppSize.compactActionButton
                  : AppSpacing.xLarge,
            ),
            // A filter can hide every child of a folder that is not empty
            child: node.children.isEmpty
                ? const EmptyFolderLabel()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
          ),
      ],
    );
  }
}
