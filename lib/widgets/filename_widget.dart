// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/git_file_status_style.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:material_ui/material_ui.dart';

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
    // A hidden file is dimmed as a hidden folder is
    final dimmedColor = fileItem.isHidden ? colorScheme.onSurfaceVariant : null;

    return TreeRow(
      icon: _getIcon(colorScheme, dimmedColor),
      name: fileItem.name,
      path: fileItem.path,
      movedFrom: fileItem.movedFrom,
      rootPath: rootPath,
      showPath: showPath,
      note: warning,
      // Git styling (strike-through, italic, color) over the dimming of a
      // hidden file, recolored when the file has a warning or is selected
      nameStyle: gitStatus
          .textStyle(
            colorScheme,
            AppTextStyle.body.copyWith(color: dimmedColor),
          )
          .copyWith(
            color: warning != null
                ? StatusTone.warning.readableIn(colorScheme)
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

  /// Returns the file-type icon widget for this entry, using the file
  /// extension or item type, in [dimmedColor] when the entry is hidden.
  Widget _getIcon(ColorScheme colorScheme, Color? dimmedColor) {
    if (fileItem.isDirectory) {
      return Icon(
        Icons.folder,
        color: dimmedColor ?? colorScheme.primary,
        size: AppIconSize.medium,
      );
    }

    // For files, use the shared icon utility
    return IconTheme.merge(
      data: IconThemeData(color: dimmedColor),
      child: FileIconUtils.getFileIcon(fileItem),
    );
  }
}
