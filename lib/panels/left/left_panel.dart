import 'package:fide/panels/left/search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../../providers/app_providers.dart';

// Screens
import 'folder_panel.dart';
import 'organized_panel.dart';
import 'git_panel.dart';

// Models
import '../../models/file_system_item.dart';

enum PanelMode { filesystem, organized, git, search }

class LeftPanel extends ConsumerStatefulWidget {
  final FileSystemItem? selectedFile;
  final String? currentProjectPath;
  final bool projectLoaded;
  final Function(FileSystemItem)? onFileSelected;
  final Function(String, int)? onJumpToLine;
  final Function(ThemeMode)? onThemeChanged;
  final Function(bool)? onProjectLoaded;
  final Function(String)? onProjectPathChanged;
  final VoidCallback? onToggleGitPanel;

  const LeftPanel({
    super.key,
    this.selectedFile,
    this.currentProjectPath,
    required this.projectLoaded,
    this.onFileSelected,
    this.onJumpToLine,
    this.onThemeChanged,
    this.onProjectLoaded,
    this.onProjectPathChanged,
    this.onToggleGitPanel,
  });

  @override
  ConsumerState<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends ConsumerState<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: PanelMode.values.length,
      vsync: this,
    );
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
      // Update the provider when tab changes
      ref.read(activeLeftPanelTabProvider.notifier).state =
          _tabController.index;

      // Trigger rebuild to update tab icons
      setState(() {});

      // Ensure selected file is visible after mode change
      if (widget.selectedFile != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // This will trigger the ExplorerScreen to ensure the file is visible
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for changes to the active left panel tab provider
    ref.listen<int>(activeLeftPanelTabProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

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
                tabs: [
                  Tab(
                    icon: Icon(
                      _tabController.index == 0
                          ? Icons.folder
                          : Icons.folder_outlined,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      _tabController.index == 1
                          ? Icons.category
                          : Icons.category_outlined,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      _tabController.index == 2
                          ? Icons.commit
                          : Icons.commit_outlined,
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      _tabController.index == 3
                          ? Icons.search
                          : Icons.search_outlined,
                    ),
                  ),
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
                ),

                // Organized tab
                OrganizedPanel(
                  onFileSelected: widget.onFileSelected,
                  selectedFile: widget.selectedFile,
                  onThemeChanged: widget.onThemeChanged,
                  onProjectLoaded: widget.onProjectLoaded,
                  onProjectPathChanged: widget.onProjectPathChanged,
                  initialProjectPath: widget.currentProjectPath,
                ),

                // Git tab - using dedicated GitPanel
                GitPanel(
                  onFileSelected: widget.onFileSelected,
                  selectedFile: widget.selectedFile,
                  projectPath: widget.currentProjectPath!,
                ),

                // Search tab - using dedicated SearchPanel
                SearchPanel(
                  projectPath: widget.currentProjectPath!,
                  onFileSelected: widget.onFileSelected,
                  onJumpToLine: widget.onJumpToLine,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
