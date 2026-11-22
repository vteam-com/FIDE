import 'package:fide/constants/constants.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A [LocationRow] naming what is at [line] of the project file at
/// [path], shown with [icon], else the file's, and [note] in its tooltip,
/// that opens the file there when tapped, the review it is in staying in
/// view: a finding's place.
class FileLocationRow extends ConsumerWidget {
  /// Creates the row of [name], at [line] of [path].
  const FileLocationRow({
    super.key,
    required this.name,
    required this.path,
    required this.line,
    required this.rootPath,
    this.icon,
    this.note,
  });

  /// The place's glyph, such as the kind of code it is in; the file's
  /// icon when null.
  final IconData? icon;

  /// 1-based line.
  final int line;

  /// What is there, such as a class name.
  final String name;

  /// A line of the tooltip under the path, such as the kind of code the
  /// place is in; none when null.
  final String? note;

  /// Absolute path of the file.
  final String path;

  /// The project's root, the tooltip showing [path] relative to it.
  final String rootPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = this.icon;
    return LocationRow(
      icon: icon == null
          ? FileIconUtils.ofPath(path)
          : Icon(icon, size: AppIconSize.medium),
      name: name,
      path: path,
      line: line,
      rootPath: rootPath,
      note: note,
      onTap: () => openFileAtLine(ref, path, line),
    );
  }
}
