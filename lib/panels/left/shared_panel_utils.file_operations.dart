part of 'shared_panel_utils.dart';

/// The tree panels' create, rename and delete flows: asks the user through
/// dialogs, does the work through [FileEntryService], refreshes the tree and
/// reports the outcome.
class FileOperations {
  final FileEntryService _files;

  /// Creates the flows on top of [_files].
  const FileOperations(this._files);

  /// Asks for a name and creates a file in the [parent] folder.
  Future<void> createNewFile(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh,
  ) => _createEntry(context, parent, onRefresh, isDirectory: false);

  /// Asks for a name and creates a folder in the [parent] folder.
  Future<void> createNewFolder(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh,
  ) => _createEntry(context, parent, onRefresh, isDirectory: true);

  /// Confirms, then deletes [node] (a folder with all its contents).
  Future<void> deleteFile(
    BuildContext context,
    ProjectNode node,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await MessageBox.confirm(
      context,
      title: 'Delete',
      message:
          'Are you sure you want to delete "${node.name}"? This action cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (!context.mounted || !confirmed) return;

    await _run(
      context,
      onRefresh,
      () => _files.delete(node.path, isDirectory: node.isDirectory),
      successMessage: 'Deleted "${node.name}"',
      failurePrefix: 'Failed to delete',
    );
  }

  /// Asks for a new name and renames [node] in place.
  Future<void> renameFile(
    BuildContext context,
    ProjectNode node,
    VoidCallback onRefresh,
  ) async {
    final result = await _promptForName(
      context,
      title: 'Rename',
      labelText: 'New name',
      hintText: 'Enter new ${node.isDirectory ? 'folder' : 'file'} name',
      confirmLabel: 'Rename',
      initialText: node.name,
    );

    if (!context.mounted ||
        result == null ||
        result.isEmpty ||
        result == node.name) {
      return;
    }

    final newPath = path.join(path.dirname(node.path), result);
    if (_files.exists(newPath)) {
      MessageBox.showError(
        context,
        'A file or folder with this name already exists',
      );
      return;
    }

    await _run(
      context,
      onRefresh,
      () => _files.rename(node.path, newPath, isDirectory: node.isDirectory),
      successMessage: 'Renamed to "$result"',
      failurePrefix: 'Failed to rename',
    );
  }

  /// Asks for a name and creates a file or folder in [parent].
  Future<void> _createEntry(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh, {
    required bool isDirectory,
  }) async {
    if (!parent.isDirectory) return;

    final kind = isDirectory ? 'folder' : 'file';
    final result = await _promptForName(
      context,
      title: isDirectory ? 'New Folder' : 'New File',
      labelText: isDirectory ? 'Folder name' : 'File name',
      hintText: isDirectory
          ? 'Enter folder name'
          : 'Enter file name (e.g., main.dart)',
      confirmLabel: 'Create',
    );

    if (!context.mounted || result == null || result.isEmpty) return;

    final targetPath = path.join(parent.path, result);
    if (_files.exists(targetPath)) {
      MessageBox.showError(context, 'A $kind with this name already exists');
      return;
    }

    await _run(
      context,
      onRefresh,
      () => _files.create(targetPath, isDirectory: isDirectory),
      successMessage: 'Created $kind "$result"',
      failurePrefix: 'Failed to create $kind',
    );
  }

  /// Shows a one-field name dialog and returns the trimmed entry, or null
  /// when cancelled.
  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    required String labelText,
    required String hintText,
    required String confirmLabel,
    String initialText = '',
  }) async {
    // Not disposed here: the dialog's field still uses it while the route
    // animates out after showDialog returns
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: labelText, hintText: hintText),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Runs [operation], refreshes the tree and reports success or failure.
  Future<void> _run(
    BuildContext context,
    VoidCallback onRefresh,
    Future<void> Function() operation, {
    required String successMessage,
    required String failurePrefix,
  }) async {
    try {
      await operation();
      onRefresh();
      if (context.mounted) MessageBox.showSuccess(context, successMessage);
    } catch (e) {
      if (context.mounted) MessageBox.showError(context, '$failurePrefix: $e');
    }
  }
}
