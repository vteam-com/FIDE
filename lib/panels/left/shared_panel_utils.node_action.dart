part of 'shared_panel_utils.dart';

/// Actions offered in the project tree's context menu, in menu order.
enum NodeAction {
  open('Open', Icons.open_in_new),
  reveal('Show in File Manager', Icons.folder_open),
  copyFullPath('Copy Full Path', Icons.content_copy),
  copyRelativePath('Copy Relative Path', Icons.content_copy),
  newFile('New File', Icons.note_add),
  newFolder('New Folder', Icons.create_new_folder),
  rename('Rename', Icons.edit),
  delete('Delete', Icons.delete);

  const NodeAction(this._label, this.icon);

  final String _label;

  /// Icon shown before the label.
  final IconData icon;

  /// Whether the action is destructive and drawn in the error color.
  bool get isDestructive => this == delete;

  /// Menu label, naming the platform's file manager for [reveal].
  String get label => switch (this) {
    reveal when Platform.isMacOS => 'Reveal in Finder',
    reveal when Platform.isWindows => 'Show in Explorer',
    _ => _label,
  };

  /// Whether the action is offered for [node]; creating entries needs a
  /// directory to create them in.
  bool appliesTo(ProjectNode node) =>
      node.isDirectory || (this != newFile && this != newFolder);
}
