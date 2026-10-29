import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/panels/left/execute_panel.dart';
import 'package:fide/panels/left/folder_panel.dart';
import 'package:fide/panels/left/git_panel.dart';
import 'package:fide/panels/left/organized_panel.dart';
import 'package:fide/panels/left/search_panel.dart';
import 'package:fide/panels/left/test_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `LeftPanel`.
class LeftPanel extends ConsumerStatefulWidget {
  final FileSystemItem? selectedFile;
  final String? currentProjectPath;
  final bool projectLoaded;
  final Function(FileSystemItem)? onFileSelected;
  final Function(String, int)? onJumpToLine;

  const LeftPanel({
    super.key,
    this.selectedFile,
    this.currentProjectPath,
    required this.projectLoaded,
    this.onFileSelected,
    this.onJumpToLine,
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
      length: LeftPanelTab.values.length,
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

  /// Handles `_handleTabChange`.
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // Update the provider when tab changes
      ref.read(activeLeftPanelTabProvider.notifier).state =
          LeftPanelTab.values[_tabController.index];

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
    ref.listen<LeftPanelTab>(activeLeftPanelTabProvider, (_, next) {
      if (_tabController.index != next.index) {
        _tabController.animateTo(next.index);
      }
    });

    return PanelTabs(
      controller: _tabController,
      showTabBar: widget.projectLoaded,
      tabs: [
        for (final tab in LeftPanelTab.values)
          Tab(
            key: tab.key,
            icon: Icon(
              _tabController.index == tab.index ? tab.selectedIcon : tab.icon,
            ),
          ),
      ],
      children: [for (final tab in LeftPanelTab.values) _buildTab(tab)],
    );
  }

  /// The panel shown under [tab].
  Widget _buildTab(LeftPanelTab tab) {
    return switch (tab) {
      LeftPanelTab.organized => OrganizedPanel(
        onFileSelected: widget.onFileSelected,
        selectedFile: widget.selectedFile,
        initialProjectPath: widget.currentProjectPath,
      ),
      LeftPanelTab.folder => FolderPanel(
        onFileSelected: widget.onFileSelected,
        selectedFile: widget.selectedFile,
        initialProjectPath: widget.currentProjectPath,
      ),
      LeftPanelTab.git => GitPanel(
        onFileSelected: widget.onFileSelected,
        selectedFile: widget.selectedFile,
        projectPath: widget.currentProjectPath!,
      ),
      LeftPanelTab.search => SearchPanel(
        projectPath: widget.currentProjectPath!,
        onFileSelected: widget.onFileSelected,
        onJumpToLine: widget.onJumpToLine,
      ),
      LeftPanelTab.run => const ExecutePanel(),
      LeftPanelTab.test => TestPanel(projectPath: widget.currentProjectPath!),
    };
  }
}
