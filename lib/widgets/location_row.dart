import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:material_ui/material_ui.dart';

/// A place in the code, such as a finding's: [icon], [name], then the
/// file name and line, the full path as the tooltip; tapping it opens
/// the file there.
class LocationRow extends StatelessWidget {
  /// Creates the row of [line] in the file at [path].
  const LocationRow({
    super.key,
    required this.icon,
    required this.name,
    required this.path,
    required this.line,
    this.rootPath,
    this.match,
    this.onTap,
  });

  /// The place's glyph.
  final Widget icon;

  /// 1-based line.
  final int line;

  /// The part of [name] matching a search, highlighted; none when null.
  final TextRange? match;

  /// What is there.
  final String name;

  /// Opens the file at [line].
  final VoidCallback? onTap;

  /// Absolute path of the file.
  final String path;

  /// Project root; the tooltip shows [path] relative to it when given.
  final String? rootPath;

  @override
  Widget build(BuildContext context) {
    return TreeRow(
      icon: icon,
      name: name,
      path: path,
      rootPath: rootPath,
      match: match,
      trailing: [
        PathText(
          path,
          line: line,
          showFolder: false,
          style: AppTextStyle.secondary(context),
        ),
      ],
      onTap: onTap,
    );
  }
}
