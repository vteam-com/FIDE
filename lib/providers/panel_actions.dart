import 'package:fide/constants/constants.dart';
import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Expands the panel shown while [visible] to its largest size, showing
/// it, or restores the size it had when [expanded] already.
void togglePanelExpanded(
  WidgetRef ref,
  StateProvider<bool> visible,
  StateProvider<bool> expanded,
) {
  final expand = !ref.read(visible) || !ref.read(expanded);
  ref.read(visible.notifier).state = true;
  ref.read(expanded.notifier).state = expand;
}

/// Shows the next panel tab after the one picked last, or the previous
/// one when [backward]: the left panel's tabs, then the right panel's,
/// looping back to the first or last.
void cyclePanelTabs(WidgetRef ref, {bool backward = false}) {
  final leftCount = LeftPanelTab.values.length;
  final count = leftCount + RightPanelTab.values.length;
  final current = ref.read(rightPanelTabPickedProvider)
      ? leftCount + ref.read(activeRightPanelTabProvider).index
      : ref.read(activeLeftPanelTabProvider).index;
  final next = (current + (backward ? -1 : 1)) % count;
  final onRight = next >= leftCount;
  ref.read(rightPanelTabPickedProvider.notifier).state = onRight;
  if (onRight) {
    ref.read(rightPanelVisibleProvider.notifier).state = true;
    ref.read(activeRightPanelTabProvider.notifier).state =
        RightPanelTab.values[next - leftCount];
  } else {
    ref.read(leftPanelVisibleProvider.notifier).state = true;
    ref.read(activeLeftPanelTabProvider.notifier).state =
        LeftPanelTab.values[next];
  }
}

/// Cycles the panel tabs when [event] is [AppShortcut.nextPanelTab] or
/// [AppShortcut.previousPanelTab], and says whether it did; for a
/// [HardwareKeyboard] handler, which sees keys before any focused widget:
/// the code editor takes Tab with any modifier, and macOS doesn't hand ⌃⇥
/// to the menu.
bool handlePanelTabKeys(WidgetRef ref, KeyEvent event) {
  final keyboard = HardwareKeyboard.instance;
  final backward = AppShortcut.previousPanelTab.accepts(event, keyboard);
  if (!backward && !AppShortcut.nextPanelTab.accepts(event, keyboard)) {
    return false;
  }
  cyclePanelTabs(ref, backward: backward);
  return true;
}
