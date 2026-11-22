import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A [LocationRow] naming what is at [line] of the project file at
/// [path], shown with the file's icon, that opens the file there when
/// tapped, the review it is in staying in view: a finding's place.
class FileLocationRow extends ConsumerWidget {
  /// Creates the row of [name], at [line] of [path].
  const FileLocationRow({
    super.key,
    required this.name,
    required this.path,
    required this.line,
    required this.rootPath,
  });

  /// 1-based line.
  final int line;

  /// What is there, such as a class name.
  final String name;

  /// Absolute path of the file.
  final String path;

  /// The project's root, the tooltip showing [path] relative to it.
  final String rootPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LocationRow(
      icon: FileIconUtils.ofPath(path),
      name: name,
      path: path,
      line: line,
      rootPath: rootPath,
      onTap: () => openFileAtLine(ref, path, line),
    );
  }
}
