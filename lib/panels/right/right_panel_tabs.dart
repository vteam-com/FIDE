import 'package:fide/panels/right/ai_panel.dart';
import 'package:fide/panels/right/analyzer_panel.dart';
import 'package:fide/panels/right/info_panel.dart';
import 'package:fide/panels/right/localization/localization_panel.dart';
import 'package:fide/panels/right/preview_panel.dart';
import 'package:fide/providers/ai_panel_busy_provider.dart';
import 'package:fide/providers/analyzer_busy_provider.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/follow_busy.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/widgets/panel_tab_spec.dart';

/// What the right panel shows under each [RightPanelTab], in tab order.
final List<PanelTabSpec<RightPanelTab>> rightPanelTabs = [
  PanelTabSpec(
    RightPanelTab.info,
    build: InfoPanel.new,
    busy: followBusy(projectQualityBusyProvider, (busy) => busy),
  ),
  PanelTabSpec(
    RightPanelTab.preview,
    build: PreviewPanel.new,
    busy: followBusy(
      previewControllerProvider,
      (preview) => preview.isBusy || preview.isGenerating,
    ),
  ),
  PanelTabSpec(
    RightPanelTab.localize,
    build: LocalizationPanel.new,
    badge: stringIssueCountProvider,
  ),
  PanelTabSpec(
    RightPanelTab.analyzer,
    build: AnalyzerPanel.new,
    busy: analyzerBusyProvider,
  ),
  PanelTabSpec(RightPanelTab.ai, build: AIPanel.new, busy: aiPanelBusyProvider),
];
