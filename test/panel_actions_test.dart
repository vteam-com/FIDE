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

  /// The bottom panel's size after each of [clicks], each one large (an
  /// ⌥-click) or not, from hidden: hide, show or large.
  Future<List<String>> bottomSizes(
    WidgetTester tester,
    List<bool> clicks,
  ) async {
    final ref = await pumpRef(tester);
    ref.read(bottomPanelVisibleProvider.notifier).state = false;
    return [
      for (final large in clicks)
        () {
          togglePanelVisible(ref, SidePanel.bottom, large: large);
          return !ref.read(bottomPanelVisibleProvider)
              ? 'hide'
              : ref.read(bottomPanelExpandedProvider)
              ? 'large'
              : 'show';
        }(),
    ];
  }

  testWidgets('a click shows or hides a panel', (tester) async {
    expect(await bottomSizes(tester, [false, false, false]), [
      'show',
      'hide',
      'show',
    ]);
  });

  testWidgets('an ⌥-click shows a panel large, or back at its own size', (
    tester,
  ) async {
    expect(await bottomSizes(tester, [true, true, true, false, false]), [
      'large',
      'show',
      'large',
      'hide',
      'show',
    ]);
  });

  testWidgets('the panel a shortcut shows becomes the active one', (
    tester,
  ) async {
    final ref = await pumpRef(tester);
    ref.read(bottomPanelVisibleProvider.notifier).state = false;

    togglePanelVisible(ref, SidePanel.bottom);
    expect(ref.read(activePanelProvider), SidePanel.bottom);

    nextLeftPanelTab(ref);
    expect(ref.read(activePanelProvider), SidePanel.left);

    nextRightPanelTab(ref);
    expect(ref.read(activePanelProvider), SidePanel.right);
  });

  testWidgets('hiding the active panel makes the editor area active', (
    tester,
  ) async {
    final ref = await pumpRef(tester);
    ref.read(rightPanelExpandedProvider.notifier).state = true;
    ref.read(activePanelProvider.notifier).state = SidePanel.right;

    togglePanelVisible(ref, SidePanel.right);

    expect(ref.read(rightPanelVisibleProvider), isFalse);
    expect(ref.read(activePanelProvider), isNull);
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
