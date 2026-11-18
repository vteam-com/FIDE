import 'package:fide/models/action_status.dart';
import 'package:fide/models/command_runs.dart';
import 'package:fide/panels/left/execute_panel.dart';
import 'package:fide/panels/left/left_panel_tabs.dart';
import 'package:fide/panels/left/test_panel.dart';
import 'package:fide/panels/right/right_panel_tabs.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_tab_header.dart';
import 'package:fide/widgets/panel_tab_spec.dart';
import 'package:fide/widget_services/project_scoped.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

/// A busy flag the ring tests read.
final _busyProvider = StateProvider<bool>((_) => true);

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

  testWidgets('busy is read from its provider, false without one', (
    tester,
  ) async {
    final withBusy = PanelTabSpec(
      RightPanelTab.ai,
      build: SizedBox.new,
      busy: _busyProvider,
    );
    const noBusy = PanelTabSpec(RightPanelTab.info, build: SizedBox.new);
    late List<bool> busy;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (_, ref, _) {
            busy = [withBusy.isBusy(ref), noBusy.isBusy(ref)];
            return const SizedBox();
          },
        ),
      ),
    );

    expect(busy, [true, false]);
  });

  test('Run and Test ring for their own runs, until an app is live', () {
    final testRun = TestPanel.actionIds.first;
    final build = ExecutePanel.actionIds.firstWhere((id) => id != 'clean');
    CommandRuns runs(Map<String, ActionStatus> statuses) =>
        CommandRuns(statuses: statuses);

    final testing = runs({testRun: ActionStatus.running});
    expect(testing.isAnyBusy(TestPanel.actionIds), isTrue);
    expect(testing.isAnyBusy(ExecutePanel.actionIds), isFalse);

    final building = runs({build: ActionStatus.running});
    expect(building.isAnyBusy(ExecutePanel.actionIds), isTrue);
    expect(building.isAnyBusy(TestPanel.actionIds), isFalse);

    final live = runs({'debug': ActionStatus.live});
    expect(live.isAnyBusy(ExecutePanel.actionIds), isFalse);
    expect(
      TestPanel.actionIds.toSet().intersection(ExecutePanel.actionIds),
      isEmpty,
    );
  });

  testWidgets('a busy tab rings its icon, an idle one does not', (
    tester,
  ) async {
    Future<void> pumpHeader({required bool busy}) => tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 1,
          child: Scaffold(
            body: TabBar(
              tabs: [
                PanelTabHeader(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'AI',
                  badgeCount: 0,
                  busy: busy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final ring = find.byType(CircularProgressIndicator);

    await pumpHeader(busy: false);
    expect(ring, findsNothing);

    await pumpHeader(busy: true);
    expect(ring, findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
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
