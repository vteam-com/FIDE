// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';

/// Widget for rendering FileSystemItem with icon, text, Git status, and interactions
class FileNameWidget extends StatelessWidget {
  const FileNameWidget({
    super.key,
    required this.fileItem,
    this.isSelected = false,
    this.showGitBadge = true,
    this.rootPath,
    this.onTap,
    this.onContextMenu,
    this.trailing,
  });

  final FileSystemItem fileItem;

  final bool isSelected;

  final ValueChanged<Offset>? onContextMenu;

  final VoidCallback? onTap;

  final String? rootPath;

  final bool showGitBadge;

  /// Extra indicator shown after the name, before the Git badge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final gitStatus = fileItem.gitStatus;
    final gitColor = gitStatus.color(context);
    final badgeText = showGitBadge ? gitStatus.badgeSymbol() : '';
    final warning = fileItem.warning;

    return TreeRow(
      icon: _getIcon(context),
      name: fileItem.name,
      path: fileItem.path,
      rootPath: rootPath,
      note: warning,
      // Git styling (strike-through, italic, color), recolored when the
      // file has a warning or is selected
      nameStyle: gitStatus
          .textStyle(context, const TextStyle())
          .copyWith(
            color: warning != null
                ? AppTheme.warningColor
                : isSelected
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
      highlighted: isSelected,
      showMenuButton: isSelected,
      onTap: onTap,
      onContextMenu: onContextMenu,
      trailing: [
        ?trailing,
        if (badgeText.isNotEmpty)
          Container(
            margin: AppPadding.selectedBadgeMargin,
            padding: AppPadding.badge,
            decoration: BoxDecoration(
              color: gitColor.withValues(alpha: AppOpacity.subtle),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: AppFontSize.badge,
                fontWeight: FontWeight.bold,
                color: gitColor,
              ),
            ),
          ),
      ],
    );
  }

  /// Returns the file-type icon widget for this entry, using the file extension or item type.
  Widget _getIcon(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (fileItem.type == FileSystemItemType.parent) {
      return Icon(
        Icons.folder_special,
        color: colorScheme.primary,
        size: AppIconSize.medium,
      );
    }

    if (fileItem.type == FileSystemItemType.directory) {
      return Icon(
        Icons.folder,
        color: colorScheme.primary,
        size: AppIconSize.medium,
      );
    }

    // For files, use the shared icon utility
    return FileIconUtils.getFileIcon(fileItem);
  }
}
