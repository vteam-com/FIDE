import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/panels/right/ai_panel.dart';
import 'package:fide/panels/right/image_details_panel.dart';
import 'package:fide/panels/right/info_panel.dart';
import 'package:fide/panels/right/localization/localization_panel.dart';
import 'package:fide/panels/right/outline_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/count_badge.dart';
import 'package:fide/widgets/empty_state.dart';
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
        final stringIssueCount = ref.watch(stringIssueCountProvider);

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
              Tooltip(
                message: tab.tooltip,
                child: Tab(
                  key: tab.key,
                  icon: CountBadge(
                    count: tab == RightPanelTab.localize ? stringIssueCount : 0,
                    child: _buildTabIcon(tab),
                  ),
                ),
              ),
          ],
          children: [for (final tab in RightPanelTab.values) _buildTab(tab)],
        );
      },
    );
  }

  /// The Outline tab: the details of the image at [iconPath] when given,
  /// else of the selected image, else the selected file's outline.
  Widget _buildOutline(String? iconPath) {
    final file = widget.selectedFile;
    final imagePath =
        iconPath ??
        (file != null && FileTypeUtils.isImageFile(file.path)
            ? file.path
            : null);
    if (imagePath != null) return ImageDetailsPanel(path: imagePath);
    if (file == null) {
      return const EmptyState(message: 'Select a file to view outline');
    }
    return OutlinePanel(
      file: file,
      onOutlineUpdate: widget.onOutlineUpdate,
      onNodeSelected: widget.onOutlineNodeSelected,
      onJumpToLine: widget.onJumpToLine,
    );
  }

  /// The panel shown under [tab].
  Widget _buildTab(RightPanelTab tab) {
    return switch (tab) {
      RightPanelTab.outline => Consumer(
        builder: (_, ref, _) {
          // The icon picked in the App Icons view, while it is open
          final icon = ref.watch(appIconsVisibleProvider)
              ? ref.watch(appIconSelectionProvider)
              : null;
          return _buildOutline(icon);
        },
      ),
      RightPanelTab.localize => LocalizationPanel(
        selectedFile: widget.selectedFile,
      ),
      RightPanelTab.ai => const AIPanel(),
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
