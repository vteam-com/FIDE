// ignore_for_file: deprecated_member_use
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/file_type_utils.dart';
import 'package:flutter/material.dart';

/// Widget for rendering FileSystemItem with icon, text, Git status, and interactions
class FileNameWidget extends StatelessWidget {
  final FileSystemItem item;
  final bool isSelected;
  final bool showGitBadge;
  final VoidCallback? onTap;
  final Function(Offset)? onContextMenu;

  const FileNameWidget({
    super.key,
    required this.item,
    this.isSelected = false,
    this.showGitBadge = true,
    this.onTap,
    this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Get Git status styling
    final gitTextStyle = item.getGitStatusTextStyle(context);
    final badgeText = showGitBadge ? item.getGitStatusBadge() : '';

    // Determine text color based on selection, hidden status, and Git status
    Color textColor;
    if (isSelected) {
      textColor = Theme.of(context).colorScheme.primary;
    } else if (item.hasGitChanges) {
      textColor = gitTextStyle.color ?? Theme.of(context).colorScheme.onSurface;
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    // Determine background color for selection
    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = Theme.of(
        context,
      ).colorScheme.primaryContainer.withOpacity(0.3);
    }

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
                child: Text(
                  item.name,
                  style: gitTextStyle.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                    color: item.getGitStatusColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.getGitStatusColor(context),
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

    if (item.type == FileSystemItemType.parent) {
      return Icon(Icons.folder_special, color: colorScheme.primary, size: 16);
    }

    if (item.type == FileSystemItemType.directory) {
      return Icon(Icons.folder, color: colorScheme.primary, size: 16);
    }

    // For files, use the shared icon utility
    return FileIconUtils.getFileIcon(item);
  }
}
