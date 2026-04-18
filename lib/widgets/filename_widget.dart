// ignore_for_file: deprecated_member_use
import 'package:fide/models/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
  });

  final FileSystemItem fileItem;

  final bool isSelected;

  final Function(Offset)? onContextMenu;

  final VoidCallback? onTap;

  final String? rootPath;

  final bool showGitBadge;

  @override
  Widget build(BuildContext context) {
    // Get Git status styling
    final gitTextStyle = fileItem.getGitStatusTextStyle(context);
    final badgeText = showGitBadge ? fileItem.getGitStatusBadge() : '';

    // Determine text color based on selection, hidden status, Git status, and warning
    Color textColor;
    if (fileItem.warning != null) {
      textColor = Colors.orange;
    } else if (isSelected) {
      textColor = Theme.of(context).colorScheme.primary;
    } else if (fileItem.hasGitChanges) {
      textColor = gitTextStyle.color ?? Theme.of(context).colorScheme.onSurface;
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    // Determine background color for selection
    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: AppOpacity.divider);
    }

    final String relativePath = p.join(
      '~',
      p.relative(fileItem.path, from: rootPath!),
    );
    final String message = fileItem.warning == null
        ? relativePath
        : '$relativePath\n\n${fileItem.warning}';

    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        color: backgroundColor,
        child: Padding(
          padding: AppPadding.listItem,
          child: Row(
            spacing: AppSpacing.tiny,
            children: [
              _getIcon(context),

              // File/directory name
              Expanded(
                child: Tooltip(
                  message: message,
                  waitDuration: AppDuration.tooltipWait,
                  child: Text(
                    fileItem.name,
                    style: gitTextStyle.copyWith(
                      fontSize: AppFontSize.body,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (badgeText.isNotEmpty)
                Container(
                  margin: AppPadding.selectedBadgeMargin,
                  padding: AppPadding.badge,
                  decoration: BoxDecoration(
                    color: fileItem
                        .getGitStatusColor(context)
                        .withValues(alpha: AppOpacity.subtle),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: AppFontSize.badge,
                      fontWeight: FontWeight.bold,
                      color: fileItem.getGitStatusColor(context),
                    ),
                  ),
                ),
              // Context menu button
              if (isSelected && onContextMenu != null)
                GestureDetector(
                  onTapDown: (details) =>
                      onContextMenu?.call(details.globalPosition),
                  child: Container(
                    width: AppSize.compactContextButton,
                    height: AppSize.compactContextButton,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.more_vert,
                      size: AppIconSize.small,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
