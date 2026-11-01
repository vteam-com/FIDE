import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A [WidgetRef] over a fresh provider scope, under a focused widget
  /// that takes every key, as the code editor takes Tab.
  Future<WidgetRef> pumpRef(WidgetTester tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (_, ref, _) {
            captured = ref;
            return Focus(
              autofocus: true,
              onKeyEvent: (_, _) => KeyEventResult.handled,
              child: const SizedBox(),
            );
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('cycles the left tabs, then the right ones, and loops', (
    tester,
  ) async {
    final ref = await pumpRef(tester);
    ref.read(activeLeftPanelTabProvider.notifier).state =
        LeftPanelTab.values.last;
    ref.read(rightPanelVisibleProvider.notifier).state = false;

    cyclePanelTabs(ref);
    expect(ref.read(rightPanelTabPickedProvider), isTrue);
    expect(ref.read(rightPanelVisibleProvider), isTrue);
    expect(ref.read(activeRightPanelTabProvider), RightPanelTab.values.first);

    ref.read(activeRightPanelTabProvider.notifier).state =
        RightPanelTab.values.last;
    cyclePanelTabs(ref);
    expect(ref.read(rightPanelTabPickedProvider), isFalse);
    expect(ref.read(activeLeftPanelTabProvider), LeftPanelTab.values.first);

    cyclePanelTabs(ref, backward: true);
    expect(ref.read(rightPanelTabPickedProvider), isTrue);
    expect(ref.read(activeRightPanelTabProvider), RightPanelTab.values.last);
  });

  testWidgets('expands a panel, showing it, then restores it', (tester) async {
    final ref = await pumpRef(tester);
    ref.read(bottomPanelVisibleProvider.notifier).state = false;

    togglePanelExpanded(
      ref,
      bottomPanelVisibleProvider,
      bottomPanelExpandedProvider,
    );
    expect(ref.read(bottomPanelVisibleProvider), isTrue);
    expect(ref.read(bottomPanelExpandedProvider), isTrue);

    togglePanelExpanded(
      ref,
      bottomPanelVisibleProvider,
      bottomPanelExpandedProvider,
    );
    expect(ref.read(bottomPanelVisibleProvider), isTrue);
    expect(ref.read(bottomPanelExpandedProvider), isFalse);
  });

  testWidgets('Ctrl-Tab cycles tabs even when a focused widget takes Tab', (
    tester,
  ) async {
    final ref = await pumpRef(tester);
    bool handler(KeyEvent event) => handlePanelTabKeys(ref, event);
    HardwareKeyboard.instance.addHandler(handler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(ref.read(activeLeftPanelTabProvider), LeftPanelTab.values[1]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(ref.read(activeLeftPanelTabProvider), LeftPanelTab.values.first);

    // Tab alone is left to the focused widget
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(ref.read(activeLeftPanelTabProvider), LeftPanelTab.values.first);
  });
}
