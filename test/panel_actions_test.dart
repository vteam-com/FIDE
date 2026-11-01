import 'package:fide/models/left_panel_tab.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/providers/panel_actions.dart';
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
      cyclePanelSize(
        ref,
        bottomPanelVisibleProvider,
        bottomPanelExpandedProvider,
      );
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
}
