import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// One file or folder row of a project tree: [icon], [name] with its path
/// as a tooltip, then [trailing] indicators.
class TreeRow extends StatelessWidget {
  /// Creates the row for the entry at [path].
  const TreeRow({
    super.key,
    required this.icon,
    required this.name,
    required this.path,
    this.rootPath,
    this.note,
    this.nameStyle,
    this.highlighted = false,
    this.showMenuButton = false,
    this.trailing = const [],
    this.onTap,
    this.onContextMenu,
  });

  /// Whether the row is filled and its name bold, marking the current or
  /// matching entry.
  final bool highlighted;

  /// The entry's glyph.
  final Widget icon;

  /// The entry's name.
  final String name;

  /// Style of [name] (color, strike-through…), on top of the row's font.
  final TextStyle? nameStyle;

  /// Extra line shown in the tooltip under the path, such as a warning.
  final String? note;

  /// Opens the context menu at the given global position.
  final ValueChanged<Offset>? onContextMenu;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Full path of the entry.
  final String path;

  /// Project root; the tooltip shows [path] relative to it when given.
  final String? rootPath;

  /// Whether to show the "more" button that opens the context menu.
  final bool showMenuButton;

  /// Indicators after the name, such as counts, badges or status icons.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final root = rootPath;
    final shownPath = root == null
        ? path
        : p.join('~', p.relative(path, from: root));
    final onContextMenu = this.onContextMenu;
    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        color: highlighted
            ? colorScheme.primaryContainer.withValues(alpha: AppOpacity.divider)
            : null,
        padding: AppPadding.listItem,
        child: Row(
          spacing: AppSpacing.tiny,
          children: [
            icon,
            Expanded(
              child: Tooltip(
                message: note == null ? shownPath : '$shownPath\n\n$note',
                waitDuration: AppDuration.tooltipWait,
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: colorScheme.onSurface,
                    fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                  ).merge(nameStyle),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ...trailing,
            if (showMenuButton && onContextMenu != null)
              MoreMenuButton(onPressed: onContextMenu),
          ],
        ),
      ),
    );
  }
}
