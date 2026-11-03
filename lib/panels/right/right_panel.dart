import 'package:fide/panels/right/right_panel_tabs.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_tab_header.dart';
import 'package:fide/widgets/panel_tabs.dart';
import 'package:fide/widgets/svg_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The panel right of the editor: one tab per [RightPanelTab], each
/// showing what [rightPanelTabs] builds for it.
class RightPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const RightPanel({super.key});

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: rightPanelTabs.length,
    initialIndex: ref.read(activeRightPanelTabProvider).index,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show the tab the provider selects, such as one a menu opened
    ref.listen<RightPanelTab>(activeRightPanelTabProvider, (_, next) {
      if (_tabController.index != next.index) {
        _tabController.animateTo(next.index);
      }
    });

    return PanelTabs(
      controller: _tabController,
      onTap: (index) {
        ref.read(activeRightPanelTabProvider.notifier).state =
            RightPanelTab.values[index];
      },
      onReselect: () => togglePanelExpanded(ref, SidePanel.right),
      tabs: [
        for (final spec in rightPanelTabs)
          PanelTabHeader(
            key: spec.tab.key,
            tooltip: spec.tab.tooltip,
            badgeCount: spec.badgeCount(ref),
            icon: _buildTabIcon(spec.tab),
          ),
      ],
      children: [for (final spec in rightPanelTabs) spec.build()],
    );
  }

  /// [tab]'s icon: its SVG tinted to the tab color, or its Material icon.
  Widget _buildTabIcon(RightPanelTab tab) {
    final svgAsset = tab.svgAsset;
    return svgAsset == null ? Icon(tab.icon) : SvgIcon(svgAsset);
  }
}
