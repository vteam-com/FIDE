import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Moves the panel shown while [visible] to its next size: hidden, then
/// its own size, then expanded to its largest ([expanded]), then hidden
/// again.
void cyclePanelSize(
  WidgetRef ref,
  StateProvider<bool> visible,
  StateProvider<bool> expanded,
) {
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

/// Shows the left panel on [tab].
void showLeftPanelTab(WidgetRef ref, LeftPanelTab tab) {
  ref.read(leftPanelVisibleProvider.notifier).state = true;
  ref.read(activeLeftPanelTabProvider.notifier).state = tab;
}

/// Shows the file at [path] in the left panel's Explorer, its folders
/// expanded and its row highlighted.
void revealInExplorer(WidgetRef ref, String path) {
  showLeftPanelTab(ref, LeftPanelTab.folder);
  ref.read(explorerRevealPathProvider.notifier).state = path;
}

/// Shows the App Icons view in the center panel.
void showAppIcons(WidgetRef ref) {
  ref.read(appIconsVisibleProvider.notifier).state = true;
}

/// Shows the right panel on [tab].
void showRightPanelTab(WidgetRef ref, RightPanelTab tab) {
  ref.read(rightPanelVisibleProvider.notifier).state = true;
  ref.read(activeRightPanelTabProvider.notifier).state = tab;
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
