import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

/// Shows [panel] at its own size when hidden, or hides it; when [large]
/// (an ⌥-click), shows it expanded to its largest instead, or back at its
/// own size when it shows so already. A shown panel becomes the active
/// one; hiding the active panel makes the editor area active.
void togglePanelVisible(WidgetRef ref, SidePanel panel, {bool large = false}) {
  final visible = panel.visibleProvider;
  final expanded = panel.expandedProvider;
  final shown = ref.read(visible);
  if (shown && !large) {
    ref.read(visible.notifier).state = false;
    if (ref.read(activePanelProvider) == panel) {
      ref.read(activePanelProvider.notifier).state = null;
    }
    return;
  }
  ref.read(expanded.notifier).state = large && !(shown && ref.read(expanded));
  _show(ref.read, panel);
}

/// Switches [panel] between its own size and expanded to its largest,
/// keeping it shown.
void togglePanelExpanded(WidgetRef ref, SidePanel panel) {
  final expanded = panel.expandedProvider;
  ref.read(expanded.notifier).state = !ref.read(expanded);
}

/// Shows the left panel's next tab, looping back to the first.
void nextLeftPanelTab(WidgetRef ref) => _nextTab(
  ref,
  LeftPanelTab.values,
  activeLeftPanelTabProvider,
  SidePanel.left,
);

/// Shows the right panel's next tab, looping back to the first.
void nextRightPanelTab(WidgetRef ref) => _nextTab(
  ref,
  RightPanelTab.values,
  activeRightPanelTabProvider,
  SidePanel.right,
);

/// Reads a provider's value, as both [Ref.read] and [WidgetRef.read] do, so
/// a panel action runs from a widget or from a provider.
typedef ProviderRead = T Function<T>(ProviderListenable<T> provider);

/// Shows the left panel on [tab] and makes it the active panel, reading
/// its state with [read] (a `ref.read`).
void showLeftPanelTab(ProviderRead read, LeftPanelTab tab) {
  _show(read, SidePanel.left);
  read(activeLeftPanelTabProvider.notifier).state = tab;
}

/// Shows the left panel on [tab], as its View menu item does; the Search
/// tab also focuses its input, seeded with the active editor's selection.
void switchLeftPanelTab(WidgetRef ref, LeftPanelTab tab) {
  if (tab == LeftPanelTab.search) {
    ref.read(projectSearchRequestProvider.notifier).state = ref
        .read(activeEditorProvider)
        .searchSeed;
  }
  showLeftPanelTab(ref.read, tab);
}

/// Shows the file at [path] in the left panel's Explorer, its folders
/// expanded and its row highlighted.
void revealInExplorer(WidgetRef ref, String path) {
  showLeftPanelTab(ref.read, LeftPanelTab.folder);
  ref.read(explorerRevealPathProvider.notifier).state = path;
}

/// Shows the settings screen in place of the window's view, or returns
/// from it to the view it replaced when [visible] is false: the Settings
/// menu item, its shortcut, the title bar's gear and close buttons and
/// Escape all go through it.
void showSettings(WidgetRef ref, {bool visible = true}) =>
    ref.read(settingsVisibleProvider.notifier).state = visible;

/// Shows [view] in the center panel.
void showCenterView(WidgetRef ref, CenterView view) {
  ref.read(centerViewProvider.notifier).state = view;
}

/// Shows the project's quality: the overview in the center panel and the
/// Info tab in the right panel, as the title bar's light bulb does.
void showProjectQuality(WidgetRef ref) {
  showCenterView(ref, CenterView.overview);
  showRightPanelTab(ref.read, RightPanelTab.info);
}

/// Closes the center view, showing the editor or the project overview.
void closeCenterView(WidgetRef ref) {
  ref.read(centerViewProvider.notifier).state = null;
}

/// Shows the right panel on [tab] and makes it the active panel, reading
/// its state with [read] (a `ref.read`).
void showRightPanelTab(ProviderRead read, RightPanelTab tab) {
  _show(read, SidePanel.right);
  read(activeRightPanelTabProvider.notifier).state = tab;
}

/// Makes [panel] the [activePanelProvider], so the workspace gradient
/// follows a keyboard shortcut or menu command as it follows a click.
void _activate(ProviderRead read, SidePanel panel) {
  read(activePanelProvider.notifier).state = panel;
}

/// Shows [panel] when hidden and makes it the active panel.
void _show(ProviderRead read, SidePanel panel) {
  read(panel.visibleProvider.notifier).state = true;
  _activate(read, panel);
}

/// Shows the tab of [tabs] after the [active] one, looping back to the
/// first, in its [panel], shown and made active.
void _nextTab<T extends Enum>(
  WidgetRef ref,
  List<T> tabs,
  StateProvider<T> active,
  SidePanel panel,
) {
  _show(ref.read, panel);
  ref.read(active.notifier).state =
      tabs[(ref.read(active).index + 1) % tabs.length];
}
