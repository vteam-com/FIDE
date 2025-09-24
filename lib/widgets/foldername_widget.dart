// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/project_node.dart';
import '../models/file_system_item.dart';

/// A reusable widget for displaying folder/file items in various panels
class FolderNameWidget extends StatelessWidget {
  final ProjectNode node;
  final bool isExpanded;
  final bool isFiltered;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(Offset)? onShowContextMenu;
  final Function(ProjectNode)? onFileSelected;

  const FolderNameWidget({
    super.key,
    required this.node,
    this.isExpanded = false,
    this.isFiltered = false,
    this.hasError = false,
    this.onTap,
    this.onLongPress,
    this.onShowContextMenu,
    this.onFileSelected,
  });

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
      textColor = colorScheme.onSurface.withOpacity(0.5);
      iconColor = colorScheme.primary.withOpacity(0.5);
    } else if (isExpanded) {
      textColor = colorScheme.primary;
      iconColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface;
      iconColor = colorScheme.primary;
    }

    // Highlight if filtered
    final backgroundColor = isFiltered
        ? colorScheme.primaryContainer.withOpacity(0.1)
        : null;

    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (TapDownDetails details) {
        onShowContextMenu!(details.globalPosition);
      },

      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        child: Row(
          spacing: 4,
          children: [
            // Icon
            _buildIcon(context, iconColor),

            // Name
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: isFiltered ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Error indicator
            if (hasError) ...[
              Icon(
                node.loadResult == LoadChildrenResult.accessDenied
                    ? Icons.lock
                    : Icons.error,
                color: colorScheme.error,
                size: 14,
              ),
            ],

            // Git status indicator
            if (node.gitStatus != GitFileStatus.clean) ...[
              _buildGitStatusIcon(colorScheme),
            ],

            // Context menu indicator (3-dot icon) when selected
            if (isExpanded)
              InkWell(
                onTapDown: (detail) =>
                    onShowContextMenu!(detail.globalPosition),
                child: Icon(
                  Icons.more_vert,
                  color: colorScheme.primary,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(context, final Color iconColor) {
    IconData iconData;

    if (hasError) {
      iconData = node.isDirectory ? Icons.folder_off : Icons.insert_drive_file;
      return Icon(iconData, color: iconColor, size: 16);
    }

    if (node.isDirectory) {
      iconData = isExpanded ? Icons.folder : Icons.folder_outlined;
      return Stack(
        alignment: AlignmentGeometry.center,
        children: [
          Icon(iconData, color: iconColor, size: 20),
          if (node.children.isNotEmpty)
            Text(
              node.children.length.toString(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isExpanded ? Colors.black : Colors.white,
              ),
            ),
        ],
      );
    }

    // File icon based on extension
    iconData = _getFileIcon(node.name);
    return Icon(iconData, color: iconColor, size: 16);
  }

  IconData _getFileIcon(String fileName) {
    final extension = p.extension(fileName).toLowerCase();

    switch (extension) {
      case '.dart':
        return Icons.code;
      case '.md':
        return Icons.description;
      case '.json':
        return Icons.data_object;
      case '.yaml':
      case '.yml':
        return Icons.settings;
      case '.txt':
        return Icons.text_snippet;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
        return Icons.image;
      case '.mp4':
      case '.avi':
      case '.mov':
        return Icons.video_file;
      case '.mp3':
      case '.wav':
        return Icons.audio_file;
      case '.zip':
      case '.tar':
      case '.gz':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildGitStatusIcon(ColorScheme colorScheme) {
    IconData iconData;
    Color iconColor;

    switch (node.gitStatus) {
      case GitFileStatus.added:
        iconData = Icons.add_circle;
        iconColor = Colors.green;
        break;
      case GitFileStatus.modified:
        iconData = Icons.edit;
        iconColor = Colors.orange;
        break;
      case GitFileStatus.untracked:
        iconData = Icons.new_releases;
        iconColor = Colors.blue;
        break;
      case GitFileStatus.clean:
      default:
        return const SizedBox(); // No icon for clean files
    }

    return Icon(iconData, color: iconColor, size: 12);
  }
}

/// Extension to provide easy access to file system item creation
extension ProjectNodeExtensions on ProjectNode {
  FileSystemItem toFileSystemItem() {
    return FileSystemItem.fromFileSystemEntity(File(path));
  }
}
