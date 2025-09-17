import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import '../screens/folder_panel.dart';

// Widgets
import 'left_panel_controls.dart';

// Models
import '../models/file_system_item.dart';

enum PanelMode { filesystem, organized, git }

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
  PanelMode _panelMode = PanelMode.filesystem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.projectLoaded)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LeftPanelControls(
                showGitPanel: widget.showGitPanel,
                isFilesystemMode: _panelMode == PanelMode.filesystem,
                isOrganizedMode: _panelMode == PanelMode.organized,
                onToggleFilesystem: _toggleFilesystemMode,
                onToggleOrganized: _toggleOrganizedMode,
                onToggleGitPanel: widget.onToggleGitPanel ?? () {},
              ),
            ),
          Expanded(
            child: FolderPanel(
              onFileSelected: widget.onFileSelected,
              selectedFile: widget.selectedFile,
              onThemeChanged: widget.onThemeChanged,
              onProjectLoaded: widget.onProjectLoaded,
              onProjectPathChanged: widget.onProjectPathChanged,
              initialProjectPath: widget.currentProjectPath,
              showGitPanel: widget.showGitPanel,
              panelMode: _panelMode,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFilesystemMode() {
    if (widget.showGitPanel) {
      widget.onToggleGitPanel?.call();
    }
    if (_panelMode != PanelMode.filesystem) {
      setState(() {
        _panelMode = PanelMode.filesystem;
      });
      // Ensure selected file is visible after mode change
      if (widget.selectedFile != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // This will trigger the ExplorerScreen to ensure the file is visible
          // The ExplorerScreen will receive the panelMode change and handle it
        });
      }
    }
  }

  void _toggleOrganizedMode() {
    if (widget.showGitPanel) {
      widget.onToggleGitPanel?.call();
    }
    if (_panelMode != PanelMode.organized) {
      setState(() {
        _panelMode = PanelMode.organized;
      });
      // Ensure selected file is visible after mode change
      if (widget.selectedFile != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // This will trigger the ExplorerScreen to ensure the file is visible
          // The ExplorerScreen will receive the panelMode change and handle it
        });
      }
    }
  }
}
