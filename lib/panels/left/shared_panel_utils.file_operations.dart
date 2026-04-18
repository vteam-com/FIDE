part of 'shared_panel_utils.dart';

/// Shared file operations utility.
class FileOperations {
  /// Opens a file node and seeds its Git status before notifying listeners.
  static void handleFileTap(
    ProjectNode node,
    PanelStateManager panelState, {
    required String? selectedFilePath,
    required void Function(FileSystemItem)? onFileSelected,
    required bool isMounted,
  }) {
    final item = FileSystemItem.fromFileSystemEntity(File(node.path));
    if (selectedFilePath == item.path) return;

    if (node.gitStatus == GitFileStatus.clean &&
        panelState.projectRoot != null) {
      panelState.seedGitStatusForFile(node);
    }

    if (onFileSelected != null && isMounted) {
      onFileSelected(item);
    }
  }

  /// Shows the creation dialog and returns the trimmed entry name.
  static Future<String?> _promptForCreationName(
    BuildContext context, {
    required String title,
    required String labelText,
    required String hintText,
  }) async {
    final TextEditingController controller = TextEditingController();
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Creates a file-system entry, refreshes the panel, and shows feedback.
  static Future<void> _createEntry(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh, {
    required String title,
    required String labelText,
    required String hintText,
    required String duplicateMessage,
    required String successPrefix,
    required Future<void> Function(String) create,
  }) async {
    if (!parent.isDirectory) return;

    final result = await _promptForCreationName(
      context,
      title: title,
      labelText: labelText,
      hintText: hintText,
    );

    if (!context.mounted) return;

    if (result == null || result.isEmpty) return;

    try {
      final targetPath = path.join(parent.path, result);

      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        MessageBox.showError(context, duplicateMessage);
        return;
      }

      await create(targetPath);

      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, '$successPrefix "$result"');
      }
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(context, 'Failed to ${title.toLowerCase()}: $e');
      }
    }
  }

  /// Handles `FileOperations.createNewFile`.
  static Future<void> createNewFile(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh,
  ) => _createNewPathEntry(context, parent, onRefresh, isDirectory: false);

  /// Handles `FileOperations.createNewFolder`.
  static Future<void> createNewFolder(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh,
  ) => _createNewPathEntry(context, parent, onRefresh, isDirectory: true);

  /// Creates either a file or folder entry using the shared creation flow.
  static Future<void> _createNewPathEntry(
    BuildContext context,
    ProjectNode parent,
    VoidCallback onRefresh, {
    required bool isDirectory,
  }) async {
    await _createEntry(
      context,
      parent,
      onRefresh,
      title: isDirectory ? 'New Folder' : 'New File',
      labelText: isDirectory ? 'Folder name' : 'File name',
      hintText: isDirectory
          ? 'Enter folder name'
          : 'Enter file name (e.g., main.dart)',
      duplicateMessage: isDirectory
          ? 'A folder with this name already exists'
          : 'A file with this name already exists',
      successPrefix: isDirectory ? 'Created folder' : 'Created file',
      create: isDirectory
          ? (targetPath) async {
              await Directory(targetPath).create(recursive: true);
            }
          : (targetPath) async {
              await File(targetPath).create(recursive: true);
            },
    );
  }

  /// Handles `FileOperations.renameFile`.
  static Future<void> renameFile(
    BuildContext context,
    ProjectNode node,
    VoidCallback onRefresh,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: node.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'New name',
            hintText: 'Enter new ${node.isDirectory ? 'folder' : 'file'} name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (result == null || result.isEmpty || result == node.name) return;

    try {
      final newPath = path.join(path.dirname(node.path), result);

      if (File(newPath).existsSync() || Directory(newPath).existsSync()) {
        MessageBox.showError(
          context,
          'A file or folder with this name already exists',
        );
        return;
      }

      if (node.isDirectory) {
        await Directory(node.path).rename(newPath);
      } else {
        await File(node.path).rename(newPath);
      }

      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, 'Renamed to "$result"');
      }
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(context, 'Failed to rename: $e');
      }
    }
  }

  /// Handles `FileOperations.deleteFile`.
  static Future<void> deleteFile(
    BuildContext context,
    ProjectNode node,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text(
          'Are you sure you want to delete "${node.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (confirmed != true) return;

    try {
      if (node.isDirectory) {
        await Directory(node.path).delete(recursive: true);
      } else {
        await File(node.path).delete();
      }

      onRefresh();

      if (context.mounted) {
        MessageBox.showSuccess(context, 'Deleted "${node.name}"');
      }
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(context, 'Failed to delete: $e');
      }
    }
  }

  /// Handles `FileOperations.revealInFileExplorer`.
  static Future<void> revealInFileExplorer(ProjectNode node) async {
    try {
      final directoryPath = node.isDirectory
          ? node.path
          : path.dirname(node.path);

      if (Platform.isMacOS) {
        await Process.run('open', [directoryPath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [directoryPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directoryPath]);
      }
    } catch (_) {
      // Error handling will be done by caller.
    }
  }
}
