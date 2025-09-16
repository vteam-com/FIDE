import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import '../screens/welcome_screen.dart';
import '../screens/editor_screen.dart';

// Models
import '../models/file_system_item.dart';

class CenterPanel extends ConsumerStatefulWidget {
  final FileSystemItem? selectedFile;
  final bool projectLoaded;
  final List<String> mruFolders;
  final VoidCallback? onOpenFolder;
  final Function(String)? onOpenMruProject;
  final Function(String)? onRemoveMruEntry;
  final VoidCallback? onContentChanged;
  final VoidCallback? onClose;

  const CenterPanel({
    super.key,
    this.selectedFile,
    required this.projectLoaded,
    required this.mruFolders,
    this.onOpenFolder,
    this.onOpenMruProject,
    this.onRemoveMruEntry,
    this.onContentChanged,
    this.onClose,
  });

  @override
  ConsumerState<CenterPanel> createState() => _CenterPanelState();
}

class _CenterPanelState extends ConsumerState<CenterPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: widget.selectedFile != null
          ? EditorScreen(
              filePath: widget.selectedFile!.path,
              onContentChanged: widget.onContentChanged,
              onClose: widget.onClose,
            )
          : !widget.projectLoaded
          ? WelcomeScreen(
              onOpenFolder: widget.onOpenFolder ?? () {},
              onCreateProject: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create new project feature coming soon!'),
                  ),
                );
              },
              mruFolders: widget.mruFolders,
              onOpenMruProject: widget.onOpenMruProject ?? (String path) {},
              onRemoveMruEntry: widget.onRemoveMruEntry ?? (String path) {},
            )
          : const Center(
              child: Text(
                'Select a file to start editing',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
    );
  }
}
