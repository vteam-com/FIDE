import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import '../screens/explorer_screen.dart';

// Models
import '../models/file_system_item.dart';

class LeftPanel extends ConsumerStatefulWidget {
  final FileSystemItem? selectedFile;
  final String? currentProjectPath;
  final bool projectLoaded;
  final Function(FileSystemItem)? onFileSelected;
  final Function(ThemeMode)? onThemeChanged;
  final Function(bool)? onProjectLoaded;
  final Function(String)? onProjectPathChanged;
  final VoidCallback? onToggleGitPanel;
  final bool showGitPanel;

  const LeftPanel({
    super.key,
    this.selectedFile,
    this.currentProjectPath,
    required this.projectLoaded,
    this.onFileSelected,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.onProjectPathChanged,
    this.onToggleGitPanel,
    this.showGitPanel = false,
  });

  @override
  ConsumerState<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends ConsumerState<LeftPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: ExplorerScreen(
        onFileSelected: widget.onFileSelected,
        selectedFile: widget.selectedFile,
        onThemeChanged: widget.onThemeChanged,
        onProjectLoaded: widget.onProjectLoaded,
        onProjectPathChanged: widget.onProjectPathChanged,
        initialProjectPath: widget.currentProjectPath,
        showGitPanel: widget.showGitPanel,
        onToggleGitPanel: widget.onToggleGitPanel,
      ),
    );
  }
}
