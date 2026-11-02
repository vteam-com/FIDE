import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A [WidgetRef] over a fresh provider scope.
  Future<WidgetRef> pumpRef(WidgetTester tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (_, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('cycles a panel through hide, min and max', (tester) async {
    final ref = await pumpRef(tester);
    ref.read(bottomPanelVisibleProvider.notifier).state = false;

    /// The bottom panel's size: hidden, min or max.
    String size() => !ref.read(bottomPanelVisibleProvider)
        ? 'hide'
        : ref.read(bottomPanelExpandedProvider)
        ? 'max'
        : 'min';
    final sizes = <String>[];
    for (var step = 0; step < 4; step++) {
      cyclePanelSize(ref, SidePanel.bottom);
      sizes.add(size());
    }

    expect(sizes, ['min', 'max', 'hide', 'min']);
  });

  testWidgets('shows the next tab of each panel, looping', (tester) async {
    final ref = await pumpRef(tester);
    ref.read(activeLeftPanelTabProvider.notifier).state =
        LeftPanelTab.values.last;
    ref.read(rightPanelVisibleProvider.notifier).state = false;

    nextLeftPanelTab(ref);
    nextRightPanelTab(ref);

    expect(ref.read(activeLeftPanelTabProvider), LeftPanelTab.values.first);
    expect(ref.read(activeRightPanelTabProvider), RightPanelTab.values[1]);
    expect(ref.read(rightPanelVisibleProvider), isTrue);
  });

  testWidgets('switching to any tab shows a hidden left panel', (tester) async {
    final ref = await pumpRef(tester);
    for (final tab in LeftPanelTab.values) {
      ref.read(leftPanelVisibleProvider.notifier).state = false;

      switchLeftPanelTab(ref, tab);

      expect(ref.read(leftPanelVisibleProvider), isTrue, reason: tab.label);
      expect(ref.read(activeLeftPanelTabProvider), tab);
    }
  });

  testWidgets('switching to Search asks it to focus its input', (tester) async {
    final ref = await pumpRef(tester);

    switchLeftPanelTab(ref, LeftPanelTab.git);
    expect(ref.read(projectSearchRequestProvider), isNull);

    switchLeftPanelTab(ref, LeftPanelTab.search);
    expect(ref.read(projectSearchRequestProvider), isEmpty);
  });

  test('each side panel has its own providers, asset and shortcut', () {
    const panels = SidePanel.values;
    for (final values in [
      panels.map((panel) => panel.visibleProvider),
      panels.map((panel) => panel.expandedProvider),
      panels.map((panel) => panel.asset),
      panels.map((panel) => panel.shortcut),
    ]) {
      expect(values.toSet(), hasLength(panels.length));
    }
    expect(SidePanel.left.visibleProvider, leftPanelVisibleProvider);
    expect(SidePanel.right.expandedProvider, rightPanelExpandedProvider);
    expect(SidePanel.bottom.tooltip, startsWith(SidePanel.bottom.commandLabel));
  });
}
