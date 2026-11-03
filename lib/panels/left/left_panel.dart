import 'package:fide/panels/left/left_panel_tabs.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_tab_header.dart';
import 'package:fide/widgets/panel_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The panel left of the editor: one tab per [LeftPanelTab], each showing
/// what [leftPanelTabs] builds for it.
class LeftPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const LeftPanel({super.key});

  @override
  ConsumerState<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends ConsumerState<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: leftPanelTabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  /// Shows the tab picked in the tab bar and updates the tab icons.
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      ref.read(activeLeftPanelTabProvider.notifier).state =
          LeftPanelTab.values[_tabController.index];
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show the tab the provider selects, such as one a menu opened
    ref.listen<LeftPanelTab>(activeLeftPanelTabProvider, (_, next) {
      if (_tabController.index != next.index) {
        _tabController.animateTo(next.index);
      }
    });

    return PanelTabs(
      controller: _tabController,
      showTabBar: ref.watch(projectLoadedProvider),
      onReselect: () => togglePanelExpanded(ref, SidePanel.left),
      tabs: [
        for (final spec in leftPanelTabs)
          PanelTabHeader(
            key: spec.tab.key,
            tooltip: spec.tab.tooltip,
            badgeCount: spec.badgeCount(ref),
            icon: Icon(
              _tabController.index == spec.tab.index
                  ? spec.tab.selectedIcon
                  : spec.tab.icon,
            ),
          ),
      ],
      children: [for (final spec in leftPanelTabs) spec.build()],
    );
  }
}
