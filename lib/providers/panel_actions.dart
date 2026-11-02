import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

/// Moves [panel] to its next size: hidden, then its own size, then
/// expanded to its largest, then hidden again.
void cyclePanelSize(WidgetRef ref, SidePanel panel) {
  final visible = panel.visibleProvider;
  final expanded = panel.expandedProvider;
  final shown = ref.read(visible);
  final wasExpanded = ref.read(expanded);
  ref.read(visible.notifier).state = !shown || !wasExpanded;
  ref.read(expanded.notifier).state = shown && !wasExpanded;
}

/// Shows the left panel's next tab, looping back to the first.
void nextLeftPanelTab(WidgetRef ref) => _nextTab(
  ref,
  LeftPanelTab.values,
  activeLeftPanelTabProvider,
  leftPanelVisibleProvider,
);

/// Shows the right panel's next tab, looping back to the first.
void nextRightPanelTab(WidgetRef ref) => _nextTab(
  ref,
  RightPanelTab.values,
  activeRightPanelTabProvider,
  rightPanelVisibleProvider,
);

/// Reads a provider's value, as both [Ref.read] and [WidgetRef.read] do, so
/// a panel action runs from a widget or from a provider.
typedef ProviderRead = T Function<T>(ProviderListenable<T> provider);

/// Shows the left panel on [tab], reading its state with [read] (a
/// `ref.read`).
void showLeftPanelTab(ProviderRead read, LeftPanelTab tab) {
  read(leftPanelVisibleProvider.notifier).state = true;
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

/// Shows the App Icons view in the center panel.
void showAppIcons(WidgetRef ref) {
  ref.read(appIconsVisibleProvider.notifier).state = true;
}

/// Shows the right panel on [tab], reading its state with [read] (a
/// `ref.read`).
void showRightPanelTab(ProviderRead read, RightPanelTab tab) {
  read(rightPanelVisibleProvider.notifier).state = true;
  read(activeRightPanelTabProvider.notifier).state = tab;
}

/// Shows the tab of [tabs] after the [active] one, looping back to the
/// first, and its panel ([visible]) when hidden.
void _nextTab<T extends Enum>(
  WidgetRef ref,
  List<T> tabs,
  StateProvider<T> active,
  StateProvider<bool> visible,
) {
  ref.read(visible.notifier).state = true;
  ref.read(active.notifier).state =
      tabs[(ref.read(active).index + 1) % tabs.length];
}
