import 'package:fide/panels/left/left_panel_tabs.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/side_panel_tabs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The panel left of the editor: one tab per [LeftPanelTab], each showing
/// what [leftPanelTabs] builds for it.
class LeftPanel extends ConsumerWidget {
  /// Creates the panel.
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SidePanelTabs(
      side: SidePanel.left,
      tabs: leftPanelTabs,
      selected: activeLeftPanelTabProvider,
      showTabBar: ref.watch(projectLoadedProvider),
    );
  }
}
