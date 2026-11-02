// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/git_file_status_style.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';

/// Widget for rendering FileSystemItem with icon, text, Git status, and interactions
class FileNameWidget extends StatelessWidget {
  const FileNameWidget({
    super.key,
    required this.fileItem,
    this.isSelected = false,
    this.showGitBadge = true,
    this.showPath = false,
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

  /// Whether the row shows the file's path, relative to [rootPath],
  /// instead of its name.
  final bool showPath;

  /// Extra indicator shown after the name, before the Git badge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gitStatus = fileItem.gitStatus;
    final gitColor = gitStatus.color(colorScheme);
    final badgeText = showGitBadge ? gitStatus.badgeSymbol() : '';
    final warning = fileItem.warning;

    return TreeRow(
      icon: _getIcon(colorScheme),
      name: fileItem.name,
      path: fileItem.path,
      rootPath: rootPath,
      showPath: showPath,
      note: warning,
      // Git styling (strike-through, italic, color), recolored when the
      // file has a warning or is selected
      nameStyle: gitStatus
          .textStyle(colorScheme, AppTextStyle.body)
          .copyWith(
            color: warning != null
                ? AppTheme.warningColor
                : isSelected
                ? colorScheme.primary
                : null,
          ),
      highlighted: isSelected,
      showMenuButton: isSelected,
      onTap: onTap,
      onContextMenu: onContextMenu,
      trailing: [
        ?trailing,
        if (badgeText.isNotEmpty)
          Padding(
            padding: AppPadding.selectedBadgeMargin,
            child: BadgeStatus(text: badgeText, color: gitColor),
          ),
      ],
    );
  }

  /// Returns the file-type icon widget for this entry, using the file extension or item type.
  Widget _getIcon(ColorScheme colorScheme) {
    if (fileItem.isDirectory) {
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
