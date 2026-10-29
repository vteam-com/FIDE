// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
  });

  final bool hasError;

  final bool isExpanded;

  final bool isFiltered;

  final ProjectNode node;

  final Function(ProjectNode)? onFileSelected;

  final Function(Offset)? onShowContextMenu;

  final VoidCallback? onTap;

  final String? rootPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on state
    Color textColor;
    Color iconColor;

    if (hasError) {
      textColor = colorScheme.error;
      iconColor = colorScheme.error;
    } else if (node.isHidden) {
      textColor = colorScheme.onSurface.withValues(alpha: AppOpacity.disabled);
      iconColor = colorScheme.primary.withValues(alpha: AppOpacity.disabled);
    } else if (isExpanded) {
      textColor = colorScheme.primary;
      iconColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface;
      iconColor = colorScheme.primary;
    }

    // Highlight if filtered
    final backgroundColor = isFiltered
        ? colorScheme.primaryContainer.withValues(alpha: AppOpacity.subtle)
        : null;

    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (TapDownDetails details) {
        onShowContextMenu?.call(details.globalPosition);
      },

      child: Container(
        color: backgroundColor,
        padding: AppPadding.listItem,
        child: Row(
          spacing: AppSpacing.tiny,
          children: [
            // Icon
            _buildIcon(context, iconColor),

            // Name
            Expanded(
              child: Tooltip(
                message: rootPath != null
                    ? p.join('~', p.relative(node.path, from: rootPath))
                    : node.path,
                waitDuration: AppDuration.tooltipWait,
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: textColor,
                    fontWeight: isFiltered ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            if (node.children.isNotEmpty)
              ContainerCounter(
                count: node.children.length,
                tooltip: 'Files in the folder',
              ),

            // Error indicator
            if (hasError) ...[
              Icon(
                node.loadResult == LoadChildrenResult.accessDenied
                    ? Icons.lock
                    : Icons.error,
                color: colorScheme.error,
                size: AppIconSize.small,
              ),
            ],

            // Git status indicator
            if (node.gitStatus != GitFileStatus.clean) ...[
              _buildGitStatusIcon(context),
            ],

            // Context menu indicator (3-dot icon) when selected
            if (isExpanded && onShowContextMenu != null)
              MoreMenuButton(onPressed: onShowContextMenu!),
          ],
        ),
      ),
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

  Widget _buildIcon(BuildContext _ /* context */, Color iconColor) {
    IconData iconData;

    if (hasError) {
      iconData = node.isDirectory ? Icons.folder_off : Icons.insert_drive_file;
      return Icon(iconData, color: iconColor, size: AppIconSize.medium);
    }

    iconData = isExpanded ? Icons.folder : Icons.folder_outlined;
    return Icon(iconData, color: iconColor, size: AppIconSize.large);
  }
}
