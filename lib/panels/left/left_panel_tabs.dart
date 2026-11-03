import 'package:fide/panels/left/execute_panel.dart';
import 'package:fide/panels/left/folder_panel.dart';
import 'package:fide/panels/left/git_panel.dart';
import 'package:fide/panels/left/organized_panel.dart';
import 'package:fide/panels/left/search_panel.dart';
import 'package:fide/panels/left/test_panel.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/panel_tab_badges.dart';
import 'package:fide/widgets/panel_tab_spec.dart';
import 'package:fide/widgets/project_scoped.dart';

/// What the left panel shows under each [LeftPanelTab], in tab order.
final List<PanelTabSpec<LeftPanelTab>> leftPanelTabs = [
  PanelTabSpec(LeftPanelTab.organized, build: OrganizedPanel.new),
  PanelTabSpec(LeftPanelTab.folder, build: FolderPanel.new),
  PanelTabSpec(
    LeftPanelTab.git,
    build: () => ProjectScoped((path) => GitPanel(projectPath: path)),
    badge: gitChangeCountProvider,
  ),
  PanelTabSpec(
    LeftPanelTab.search,
    build: () => ProjectScoped((path) => SearchPanel(projectPath: path)),
  ),
  PanelTabSpec(LeftPanelTab.run, build: ExecutePanel.new),
  PanelTabSpec(
    LeftPanelTab.test,
    build: () => ProjectScoped((path) => TestPanel(projectPath: path)),
  ),
];
