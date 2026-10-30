// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';

/// A reusable widget for displaying folder/file items in various panels
class FolderNameWidget extends StatelessWidget {
  const FolderNameWidget({
    super.key,
    required this.node,
    this.isExpanded = false,
    this.isFiltered = false,
    this.hasError = false,
    this.rootPath,
    this.onTap,
    this.onShowContextMenu,
    this.onFileSelected,
    this.trailing,
  });

  final bool hasError;

  final bool isExpanded;

  final bool isFiltered;

  final ProjectNode node;

  final Function(ProjectNode)? onFileSelected;

  final ValueChanged<Offset>? onShowContextMenu;

  final VoidCallback? onTap;

  final String? rootPath;

  /// Shown after the name, before the child counter, e.g. a warning.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color? nameColor;
    final Color iconColor;
    if (hasError) {
      nameColor = colorScheme.error;
      iconColor = colorScheme.error;
    } else if (node.isHidden) {
      nameColor = colorScheme.onSurface.withValues(alpha: AppOpacity.disabled);
      iconColor = colorScheme.primary.withValues(alpha: AppOpacity.disabled);
    } else {
      nameColor = isExpanded ? colorScheme.primary : null;
      iconColor = colorScheme.primary;
    }

    return TreeRow(
      icon: Icon(
        hasError
            ? (node.isDirectory ? Icons.folder_off : Icons.insert_drive_file)
            : (isExpanded ? Icons.folder : Icons.folder_outlined),
        color: iconColor,
        size: AppIconSize.medium,
      ),
      name: node.name,
      path: node.path,
      rootPath: rootPath,
      nameStyle: TextStyle(color: nameColor),
      highlighted: isFiltered,
      showMenuButton: isExpanded,
      onTap: onTap,
      onContextMenu: onShowContextMenu,
      trailing: [
        ?trailing,
        if (node.children.isNotEmpty)
          ContainerCounter(
            count: node.children.length,
            tooltip: 'Files in the folder',
          ),
        if (hasError)
          Icon(
            node.loadResult == LoadChildrenResult.accessDenied
                ? Icons.lock
                : Icons.error,
            color: colorScheme.error,
            size: AppIconSize.small,
          ),
        if (node.gitStatus != GitFileStatus.clean) _buildGitStatusIcon(context),
      ],
    );
  }

  /// Small icon marking the folder's Git status; empty when unmarked.
  Widget _buildGitStatusIcon(BuildContext context) {
    final icon = node.gitStatus.icon;
    if (icon == null) return const SizedBox();
    return Icon(
      icon,
      color: node.gitStatus.color(context),
      size: AppIconSize.tiny,
    );
  }
}
