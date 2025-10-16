// ignore_for_file: deprecated_member_use
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/file_type_utils.dart';
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
      ).colorScheme.primaryContainer.withValues(alpha: 0.3);
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Row(
            spacing: 4,
            children: [
              _getIcon(context),

              // File/directory name
              Expanded(
                child: Tooltip(
                  message: message,
                  waitDuration: Duration(seconds: 1),
                  child: Text(
                    fileItem.name,
                    style: gitTextStyle.copyWith(
                      fontSize: 13,
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
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: fileItem
                        .getGitStatusColor(context)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
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
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.more_vert,
                      size: 14,
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

  Widget _getIcon(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (fileItem.type == FileSystemItemType.parent) {
      return Icon(Icons.folder_special, color: colorScheme.primary, size: 16);
    }

    if (fileItem.type == FileSystemItemType.directory) {
      return Icon(Icons.folder, color: colorScheme.primary, size: 16);
    }

    // For files, use the shared icon utility
    return FileIconUtils.getFileIcon(fileItem);
  }
}
