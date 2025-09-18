import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import 'folder_panel.dart';

// Models
import '../../models/file_system_item.dart';

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

class _LeftPanelState extends ConsumerState<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PanelMode _panelMode = PanelMode.filesystem;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      final newMode = PanelMode.values[_tabController.index];
      if (newMode != _panelMode) {
        setState(() {
          _panelMode = newMode;
        });

        // Ensure selected file is visible after mode change
        if (widget.selectedFile != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // This will trigger the ExplorerScreen to ensure the file is visible
          });
        }
      }
    }
  }

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
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.folder)),
                  Tab(icon: Icon(Icons.folder_special)),
                  Tab(icon: Icon(Icons.account_tree)),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                physics:
                    const NeverScrollableScrollPhysics(), // Disable swipe gestures
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics:
                  const NeverScrollableScrollPhysics(), // Disable swipe gestures
              children: [
                // Files tab
                FolderPanel(
                  onFileSelected: widget.onFileSelected,
                  selectedFile: widget.selectedFile,
                  onThemeChanged: widget.onThemeChanged,
                  onProjectLoaded: widget.onProjectLoaded,
                  onProjectPathChanged: widget.onProjectPathChanged,
                  initialProjectPath: widget.currentProjectPath,
                  showGitPanel: false,
                  panelMode: PanelMode.filesystem,
                ),

                // Organized tab
                FolderPanel(
                  onFileSelected: widget.onFileSelected,
                  selectedFile: widget.selectedFile,
                  onThemeChanged: widget.onThemeChanged,
                  onProjectLoaded: widget.onProjectLoaded,
                  onProjectPathChanged: widget.onProjectPathChanged,
                  initialProjectPath: widget.currentProjectPath,
                  showGitPanel: false,
                  panelMode: PanelMode.organized,
                ),

                // Git tab
                FolderPanel(
                  onFileSelected: widget.onFileSelected,
                  selectedFile: widget.selectedFile,
                  onThemeChanged: widget.onThemeChanged,
                  onProjectLoaded: widget.onProjectLoaded,
                  onProjectPathChanged: widget.onProjectPathChanged,
                  initialProjectPath: widget.currentProjectPath,
                  showGitPanel: true,
                  panelMode: PanelMode.filesystem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
