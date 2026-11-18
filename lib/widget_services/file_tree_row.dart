import 'package:fide/models/file_system_item.dart';
import 'package:fide/widget_services/file_outline.dart';
import 'package:fide/widget_services/selected_file_builder.dart';
import 'package:fide/widgets/filename_widget.dart';
import 'package:fide/widgets/tree_branch.dart';
import 'package:material_ui/material_ui.dart';

/// A file's row in a project tree (Explorer, Organized) and, while it is
/// the selected file, its outline nested under it.
class FileTreeRow extends StatelessWidget {
  /// Creates the row of [fileItem].
  const FileTreeRow({
    super.key,
    required this.fileItem,
    this.isRevealed = false,
    this.rootPath,
    this.onTap,
    this.onContextMenu,
    this.trailing,
  });

  /// The file shown.
  final FileSystemItem fileItem;

  /// Whether the file was revealed in the tree, highlighted like the
  /// selected file.
  final bool isRevealed;

  /// Opens the file's context menu at a global position.
  final ValueChanged<Offset>? onContextMenu;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Project root, for paths shown relative to it.
  final String? rootPath;

  /// Extra indicator shown after the name, before the Git badge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Selecting a file rebuilds its row and the one it leaves, not the
    // whole tree
    return SelectedFileBuilder(
      path: fileItem.path,
      builder: (_, isSelected) => TreeBranch(
        header: FileNameWidget(
          fileItem: fileItem,
          isSelected: isRevealed || isSelected,
          rootPath: rootPath,
          onTap: onTap,
          onContextMenu: onContextMenu,
          trailing: trailing,
        ),
        isExpanded: isSelected,
        children: [FileOutline(path: fileItem.path)],
      ),
    );
  }
}
