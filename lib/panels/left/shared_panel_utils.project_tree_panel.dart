part of 'shared_panel_utils.dart';

/// Base widget for the left-hand project tree views (Folder and Organized),
/// holding the inputs they share; pair it with [ProjectTreePanelState].
abstract class ProjectTreePanel extends ConsumerStatefulWidget {
  /// Creates a project tree panel.
  const ProjectTreePanel({
    super.key,
    this.onFileSelected,
    this.selectedFile,
    this.initialProjectPath,
  });

  /// Root path of the project open when the panel is created.
  final String? initialProjectPath;

  /// Called when the user opens a file from the tree.
  final Function(FileSystemItem)? onFileSelected;

  /// File currently open in the editor, highlighted in the tree.
  final FileSystemItem? selectedFile;
}
