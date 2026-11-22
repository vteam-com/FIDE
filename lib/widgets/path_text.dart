import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// A file path as FIDE shows it everywhere: its folders dimmed, then the
/// file name bolder at full strength, an optional `:line` and, for a file
/// that moved, `← ` and where it moved from, dimmed.
///
/// The path shows in full, or relative to [rootPath] when given and inside
/// it; [showFolder] false shows the name alone. On one line (the default)
/// the folders are cut short so the name stays visible; [selectable] lets
/// it wrap and be selected instead.
class PathText extends StatelessWidget {
  /// Creates the display of [path].
  const PathText(
    this.path, {
    super.key,
    this.rootPath,
    this.line,
    this.movedFrom,
    this.showFolder = true,
    this.selectable = false,
    this.style = AppTextStyle.body,
  });

  /// Between the path and where it moved from.
  static const String _movedArrow = ' ← ';

  /// 1-based line shown after the name, such as a finding's location.
  final int? line;

  /// Where the file moved from, as an absolute path, shown after the name
  /// as the path itself is; null when it didn't move.
  final String? movedFrom;

  /// The file or folder, as an absolute path.
  final String path;

  /// Folder [path] is shown relative to; the full path when null or when
  /// [path] is outside it.
  final String? rootPath;

  /// Whether the path wraps and can be selected, rather than staying on
  /// one line.
  final bool selectable;

  /// Whether to show the folders before the name.
  final bool showFolder;

  /// Size, color and decoration of the text; the name is drawn bold on top
  /// of it and the folders dimmed.
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final shown = shownPath(path, rootPath);
    final directory = p.dirname(shown);
    final folder = showFolder && directory != '.'
        ? '$directory${p.separator}'
        : '';
    final line = this.line;
    final name = '${p.basename(shown)}${line == null ? '' : ':$line'}';

    final colorScheme = Theme.of(context).colorScheme;
    // The folders dimmed as all secondary text is, never by transparency,
    // which would read below AA
    final folderStyle = style.copyWith(color: colorScheme.onSurfaceVariant);
    final nameStyle = style
        .merge(AppTextStyle.strong)
        .copyWith(color: style.color ?? colorScheme.onSurface);
    final movedFrom = this.movedFrom;
    final origin = movedFrom == null
        ? ''
        : '$_movedArrow${shownPath(movedFrom, rootPath)}';

    if (selectable) {
      return SelectableText.rich(
        TextSpan(
          children: [
            if (folder.isNotEmpty) TextSpan(text: folder, style: folderStyle),
            TextSpan(text: name, style: nameStyle),
            if (origin.isNotEmpty) TextSpan(text: origin, style: folderStyle),
          ],
        ),
      );
    }
    final nameText = Text(
      name,
      style: nameStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (folder.isEmpty && origin.isEmpty) return nameText;
    // The name takes what it needs, up to the whole width; the folders and
    // where the file moved from share the rest, cut short
    Widget dimmed(String text) => Flexible(
      child: Text(
        text,
        style: folderStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return LayoutBuilder(
      builder: (_, constraints) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (folder.isNotEmpty) dimmed(folder),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: nameText,
          ),
          if (origin.isNotEmpty) dimmed(origin),
        ],
      ),
    );
  }

  /// [path] as shown: relative to [rootPath] when given and inside it,
  /// else in full.
  static String shownPath(String path, String? rootPath) =>
      rootPath != null && p.isWithin(rootPath, path)
      ? p.relative(path, from: rootPath)
      : path;
}
