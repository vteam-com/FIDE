part of 'shared_panel_utils.dart';

/// What the project tree's context menu offers besides the [FileAction]s,
/// changing the tree itself, in menu order.
enum NodeAction {
  newFile('New File…', Icons.note_add),
  newFolder('New Folder…', Icons.create_new_folder),
  rename('Rename…', Icons.drive_file_rename_outline),
  delete('Delete', Icons.delete);

  const NodeAction(this.label, this.icon);

  /// Menu label.
  final String label;

  /// Icon shown before the label.
  final IconData icon;

  /// Whether the action is destructive and drawn in the error color.
  bool get isDestructive => this == delete;

  /// Whether the action is offered for [node]; creating entries needs a
  /// directory to create them in.
  bool appliesTo(ProjectNode node) =>
      node.isDirectory || (this != newFile && this != newFolder);
}
