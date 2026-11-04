import 'package:fide/panels/right/ai_panel.dart';
import 'package:fide/panels/right/info_panel.dart';
import 'package:fide/panels/right/localization/localization_panel.dart';
import 'package:fide/panels/right/outline_tab.dart';
import 'package:fide/panels/right/preview_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/widgets/panel_tab_spec.dart';

/// What the right panel shows under each [RightPanelTab], in tab order.
final List<PanelTabSpec<RightPanelTab>> rightPanelTabs = [
  PanelTabSpec(RightPanelTab.outline, build: OutlineTab.new),
  PanelTabSpec(RightPanelTab.preview, build: PreviewPanel.new),
  PanelTabSpec(
    RightPanelTab.localize,
    build: LocalizationPanel.new,
    badge: stringIssueCountProvider,
  ),
  PanelTabSpec(RightPanelTab.ai, build: AIPanel.new),
  PanelTabSpec(RightPanelTab.info, build: InfoPanel.new),
];
