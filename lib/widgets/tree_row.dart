import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// One row of a tree (files, folders, outline symbols, search results):
/// [icon], [name] with its path as a tooltip, then [trailing] indicators.
class TreeRow extends StatelessWidget {
  /// Creates the row for [name].
  const TreeRow({
    super.key,
    required this.icon,
    required this.name,
    this.path,
    this.depth = 0,
    this.rootPath,
    this.note,
    this.nameStyle,
    this.highlighted = false,
    this.showMenuButton = false,
    this.trailing = const [],
    this.onTap,
    this.onContextMenu,
  });

  /// Nesting level; each level indents the row by one step.
  final int depth;

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

  /// Full path of the entry, shown as the tooltip; no tooltip when null.
  final String? path;

  /// Project root; the tooltip shows [path] relative to it when given.
  final String? rootPath;

  /// Whether to show the "more" button that opens the context menu.
  final bool showMenuButton;

  /// Indicators after the name, such as counts, badges or status icons.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = this.path;
    final root = rootPath;
    final shownPath = path == null || root == null
        ? path
        : p.join('~', p.relative(path, from: root));
    final tooltip = note == null ? shownPath : '${shownPath ?? ''}\n\n$note';
    final text = Text(
      name,
      style: (highlighted ? AppTextStyle.bodyStrong : AppTextStyle.body).merge(
        nameStyle,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
    final onContextMenu = this.onContextMenu;
    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        color: highlighted
            ? colorScheme.primaryContainer.withValues(alpha: AppOpacity.divider)
            : null,
        padding: AppPadding.listItem.add(
          EdgeInsets.only(left: AppSpacing.xLarge * depth),
        ),
        child: Row(
          spacing: AppSpacing.tiny,
          children: [
            icon,
            Expanded(
              child: tooltip == null
                  ? text
                  : Tooltip(
                      message: tooltip,
                      waitDuration: AppDuration.tooltipWait,
                      child: text,
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
