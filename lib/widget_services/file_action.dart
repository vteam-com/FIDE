import 'package:fide/models/readable_error.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/panel_actions.dart' as panel_actions;
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// What can be done with a file or folder wherever it shows: the one list
/// behind the project trees' context menu and the buttons under a file's
/// details, so each action reads and works the same everywhere.
enum FileAction {
  /// Opens the file in FIDE's editor, from the center view showing.
  open('Open in FIDE', Icons.open_in_new),

  /// Opens the file in the app the system opens its type with.
  openWithDefaultApp('Open in Default App', Icons.launch),

  /// Shows the file in FIDE's Explorer.
  revealInExplorer('Reveal in FIDE Explorer', Icons.account_tree_outlined),

  /// Shows the file or folder in the system's file manager.
  revealInFileManager('Reveal in', Icons.folder_open),

  /// Copies the full path.
  copyFullPath('Copy Full Path', Icons.copy, isCopy: true),

  /// Copies the path from the project's folder.
  copyRelativePath(
    'Copy Relative Path',
    Icons.subdirectory_arrow_right,
    isCopy: true,
  ),

  /// Copies the name.
  copyName('Copy Name', Icons.insert_drive_file_outlined, isCopy: true);

  const FileAction(this._label, this.icon, {this.isCopy = false});

  final String _label;

  /// Icon shown before the label.
  final IconData icon;

  /// Whether the action copies something about the file to the clipboard.
  final bool isCopy;

  /// The label, naming [shell]'s file manager for [revealInFileManager].
  String labelIn(DesktopShell shell) =>
      this == revealInFileManager ? '$_label ${shell.fileManagerName}' : _label;

  /// Whether the action applies to the entry at [path], a folder when
  /// [isDirectory], in the project at [projectPath]: only files open, and
  /// only the project's entries have a relative path.
  bool appliesTo(
    String path, {
    required bool isDirectory,
    required String? projectPath,
  }) => switch (this) {
    open || openWithDefaultApp => !isDirectory,
    copyRelativePath => projectPath != null && p.isWithin(projectPath, path),
    _ => true,
  };

  /// Whether the project trees' context menu offers the action: revealing
  /// an entry in FIDE's Explorer is for entries shown elsewhere.
  bool get inProjectTrees => this != revealInExplorer;

  /// Runs the action on the entry at [path], a folder when [isDirectory];
  /// tells the user when it fails.
  Future<void> run(
    BuildContext context,
    WidgetRef ref,
    String path, {
    bool isDirectory = false,
  }) async {
    switch (this) {
      case open:
        openFromCenterView(ref, path);
      case openWithDefaultApp:
        await _orShowError(
          context,
          path,
          'open',
          () => ref.read(desktopShellProvider).openWithDefaultApp(path),
        );
      case revealInExplorer:
        panel_actions.revealInExplorer(ref, path);
      case revealInFileManager:
        final shell = ref.read(desktopShellProvider);
        await _orShowError(
          context,
          path,
          'reveal',
          () => isDirectory
              ? shell.revealInFileManager(path)
              : shell.revealFile(path),
        );
      case copyFullPath:
        MessageBox.copyToClipboard(
          context,
          path,
          confirmation: 'Full path copied to clipboard',
        );
      case copyRelativePath:
        final projectPath = ref.read(currentProjectPathProvider);
        if (projectPath == null) return;
        MessageBox.copyToClipboard(
          context,
          p.relative(path, from: projectPath),
          confirmation: 'Relative path copied to clipboard',
        );
      case copyName:
        MessageBox.copyToClipboard(
          context,
          p.basename(path),
          confirmation: 'Name copied to clipboard',
        );
    }
  }

  /// Runs [action], telling the user when it fails to [verb] [path].
  static Future<void> _orShowError(
    BuildContext context,
    String path,
    String verb,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(
          context,
          'Failed to $verb ${p.basename(path)}: ${ReadableError.describe(e)}',
        );
      }
    }
  }
}
