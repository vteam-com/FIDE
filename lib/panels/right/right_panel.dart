import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/panels/right/ai_panel.dart';
import 'package:fide/panels/right/info_panel.dart';
import 'package:fide/panels/right/localization/localization_panel.dart';
import 'package:fide/panels/right/outline_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Represents `RightPanel`.
class RightPanel extends StatefulWidget {
  const RightPanel({
    super.key,
    this.selectedFile,
    this.onOutlineUpdate,
    this.onOutlineNodeSelected,
    this.onJumpToLine,
  });

  /// Opens a file at a 1-based line, e.g. a caller listed by the outline.
  final Function(String, int)? onJumpToLine;

  final Function(int, int)? onOutlineNodeSelected;

  final Function(VoidCallback)? onOutlineUpdate;

  final FileSystemItem? selectedFile;

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: RightPanelTab.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final activeTab = ref.watch(activeRightPanelTabProvider);

        // Update TabController to match the provider
        if (_tabController.index != activeTab.index) {
          _tabController.animateTo(activeTab.index);
        }

        return PanelTabs(
          controller: _tabController,
          onTap: (index) {
            ref.read(activeRightPanelTabProvider.notifier).state =
                RightPanelTab.values[index];
          },
          tabs: [
            for (final tab in RightPanelTab.values)
              Tab(key: tab.key, icon: _buildTabIcon(tab)),
          ],
          children: [for (final tab in RightPanelTab.values) _buildTab(tab)],
        );
      },
    );
  }

  /// The panel shown under [tab].
  Widget _buildTab(RightPanelTab tab) {
    return switch (tab) {
      RightPanelTab.outline =>
        widget.selectedFile != null
            ? OutlinePanel(
                file: widget.selectedFile!,
                onOutlineUpdate: widget.onOutlineUpdate,
                onNodeSelected: widget.onOutlineNodeSelected,
                onJumpToLine: widget.onJumpToLine,
              )
            : const Center(
                child: Text(
                  'Select a file to view outline',
                  style: TextStyle(
                    fontSize: AppFontSize.label,
                    color: Colors.grey,
                  ),
                ),
              ),
      RightPanelTab.localize => LocalizationPanel(
        selectedFile: widget.selectedFile,
      ),
      RightPanelTab.ai => AIPanel(selectedFile: widget.selectedFile),
      RightPanelTab.info => const InfoPanel(),
    };
  }

  /// [tab]'s icon: its SVG tinted to the tab color, or its Material icon.
  Widget _buildTabIcon(RightPanelTab tab) {
    final svgAsset = tab.svgAsset;
    if (svgAsset == null) return Icon(tab.icon);
    return Builder(
      builder: (context) => SvgPicture.asset(
        svgAsset,
        width: AppIconSize.xLarge,
        height: AppIconSize.xLarge,
        colorFilter: ColorFilter.mode(
          IconTheme.of(context).color!,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
