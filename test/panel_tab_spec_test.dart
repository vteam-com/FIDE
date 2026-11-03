import 'package:fide/panels/left/left_panel_tabs.dart';
import 'package:fide/panels/right/right_panel_tabs.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_tab_spec.dart';
import 'package:fide/widgets/project_scoped.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

/// A count the badge tests read.
final _countProvider = StateProvider<int>((_) => 3);

void main() {
  test('every tab of each panel has a spec, in tab order', () {
    expect(leftPanelTabs.map((spec) => spec.tab), LeftPanelTab.values);
    expect(rightPanelTabs.map((spec) => spec.tab), RightPanelTab.values);
  });

  testWidgets('a badge is read from its provider, zero without one', (
    tester,
  ) async {
    final withBadge = PanelTabSpec(
      LeftPanelTab.git,
      build: SizedBox.new,
      badge: _countProvider,
    );
    const noBadge = PanelTabSpec(LeftPanelTab.run, build: SizedBox.new);
    late List<int> counts;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (_, ref, _) {
            counts = [withBadge.badgeCount(ref), noBadge.badgeCount(ref)];
            return const SizedBox();
          },
        ),
      ),
    );

    expect(counts, [3, 0]);
  });

  testWidgets('a project panel gets the open project, else the placeholder', (
    tester,
  ) async {
    final shown = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProjectScoped((path) {
            shown.add(path);
            return const Text('panel');
          }),
        ),
      ),
    );
    expect(find.byType(NoProjectPlaceholder), findsOneWidget);

    final element = tester.element(find.byType(ProjectScoped));
    ProviderScope.containerOf(element)
            .read(currentProjectPathProvider.notifier)
            .state =
        '/demo';
    await tester.pump();

    expect(find.text('panel'), findsOneWidget);
    expect(shown, ['/demo']);
  });
}
