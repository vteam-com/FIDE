import 'package:fide/constants/constants.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/priority_row.dart';
import 'package:material_ui/material_ui.dart';
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
    this.match,
    this.showMenuButton = false,
    this.showPath = false,
    this.trailing = const [],
    this.onTap,
    this.onContextMenu,
  });

  /// The row of the file at [path], with its icon, shown as its path
  /// relative to [rootPath]: folders dimmed and the file name bold, as
  /// [PathText] shows every path.
  TreeRow.filePath(
    String path, {
    Key? key,
    String? rootPath,
    bool highlighted = false,
    VoidCallback? onTap,
  }) : this(
         key: key,
         icon: FileIconUtils.ofPath(path),
         name: p.basename(path),
         path: path,
         rootPath: rootPath,
         highlighted: highlighted,
         showPath: true,
         onTap: onTap,
       );

  /// Nesting level; each level indents the row by one step.
  final int depth;

  /// Whether the row is filled and its name bold, marking the current or
  /// matching entry.
  final bool highlighted;

  /// The entry's glyph.
  final Widget icon;

  /// The part of [name] matching a search, highlighted; none when null.
  final TextRange? match;

  /// The entry's name.
  final String name;

  /// Style of [name] (color, strike-through…), on top of the row's font.
  final TextStyle? nameStyle;

  /// Extra line shown in the tooltip (under the path, when given), such as
  /// a warning or a date.
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

  /// Whether the row shows [path], relative to [rootPath], instead of
  /// [name].
  final bool showPath;

  /// Indicators after the name, such as counts, badges or status icons.
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final root = rootPath;
    final shownPath = path == null ? null : PathText.shownPath(path, root);
    final tooltipLines = [?shownPath, ?note];
    final tooltip = tooltipLines.isEmpty ? null : tooltipLines.join('\n\n');
    final style = (highlighted ? AppTextStyle.bodyStrong : AppTextStyle.body)
        .merge(nameStyle);
    final text = showPath && path != null
        ? PathText(path, rootPath: root, style: style)
        : Text.rich(
            _highlighted(context, match),
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
    final onContextMenu = this.onContextMenu;
    final extras = [
      ...trailing,
      if (showMenuButton && onContextMenu != null)
        MoreMenuButton(onPressed: onContextMenu),
    ];
    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        color: highlighted ? AppTheme.selectedFill(context) : null,
        padding: AppPadding.listItem.add(
          EdgeInsets.only(left: AppSpacing.xLarge * depth),
        ),
        // In a narrow panel the name keeps its room; the indicators hide
        child: PriorityRow(
          spacing: AppSpacing.tiny,
          leading: icon,
          title: tooltip == null
              ? text
              : Tooltip(
                  message: tooltip,
                  waitDuration: AppDuration.tooltipWait,
                  child: text,
                ),
          trailing: extras.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.tiny,
                  children: extras,
                ),
        ),
      ),
    );
  }

  /// [name] with the part in [match] highlighted as a search match.
  TextSpan _highlighted(BuildContext context, TextRange? match) {
    if (match == null || !match.isValid || match.end > name.length) {
      return TextSpan(text: name);
    }
    return TextSpan(
      children: [
        TextSpan(text: match.textBefore(name)),
        TextSpan(
          text: match.textInside(name),
          style: AppTextStyle.match(context),
        ),
        TextSpan(text: match.textAfter(name)),
      ],
    );
  }
}
