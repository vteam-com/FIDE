import 'package:fide/panels/right/right_panel_tabs.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/side_panel_tabs.dart';
import 'package:material_ui/material_ui.dart';

/// The panel right of the editor: one tab per [RightPanelTab], each
/// showing what [rightPanelTabs] builds for it.
class RightPanel extends StatelessWidget {
  /// Creates the panel.
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SidePanelTabs(
      side: SidePanel.right,
      tabs: rightPanelTabs,
      selected: activeRightPanelTabProvider,
    );
  }
}
