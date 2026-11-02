import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// A file path as FIDE shows it everywhere: its folders dimmed, then the
/// file name bolder at full strength, and an optional `:line`.
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
    this.showFolder = true,
    this.selectable = false,
    this.style = AppTextStyle.body,
  });

  /// 1-based line shown after the name, such as a finding's location.
  final int? line;

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

    final color = style.color ?? Theme.of(context).colorScheme.onSurface;
    final folderStyle = style.copyWith(
      color: color.withAlpha(AppAlpha.pathPrefix),
    );
    final nameStyle = style.merge(AppTextStyle.strong).copyWith(color: color);

    if (selectable) {
      return SelectableText.rich(
        TextSpan(
          children: [
            if (folder.isNotEmpty) TextSpan(text: folder, style: folderStyle),
            TextSpan(text: name, style: nameStyle),
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
    if (folder.isEmpty) return nameText;
    // The name takes what it needs, up to the whole width; the folders get
    // the rest
    return LayoutBuilder(
      builder: (_, constraints) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              folder,
              style: folderStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: nameText,
          ),
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
