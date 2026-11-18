import 'package:fide/models/action_status.dart';
import 'package:fide/models/hot_reload.dart';
import 'package:fide/widgets/action_list.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Shows a Run Debug action at [status], with the hot reload controls,
  /// recording the controls run in [ran].
  Future<void> pumpDebug(
    WidgetTester tester,
    ActionStatus status, [
    List<HotReload>? ran,
  ]) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ActionList(
          actions: [
            PanelAction(
              id: 'debug',
              title: 'Run Debug',
              description: 'Run',
              details: '',
              icon: Icons.bug_report_rounded,
              onRun: () {},
              onStop: () {},
              status: status,
              liveControls: [
                for (final kind in HotReload.values)
                  LiveControl(
                    icon: kind.icon,
                    tooltip: kind.tooltip,
                    status: kind.status,
                    onRun: () => ran?.add(kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  final reload = find.byIcon(HotReload.reload.icon);
  final restart = find.byIcon(HotReload.restart.icon);
  final ring = find.byType(CircularProgressIndicator);

  /// The button showing [icon].
  IconButton buttonOf(WidgetTester tester, Finder icon) =>
      tester.widget(find.ancestor(of: icon, matching: find.byType(IconButton)));

  testWidgets('hot reload controls show only once the app is live', (
    tester,
  ) async {
    await pumpDebug(tester, ActionStatus.running);
    expect(reload, findsNothing);
    expect(ring, findsOneWidget);

    final ran = <HotReload>[];
    await pumpDebug(tester, ActionStatus.live, ran);
    expect(ring, findsNothing);
    await tester.tap(reload);
    await tester.tap(restart);
    expect(ran, HotReload.values);
  });

  testWidgets('the reload running rings its button, the other waits', (
    tester,
  ) async {
    await pumpDebug(tester, ActionStatus.restarting);

    TaskButton taskOf(Finder icon) => tester.widget(
      find.ancestor(of: icon, matching: find.byType(TaskButton)),
    );
    expect(ring, findsOneWidget);
    expect(taskOf(restart).running, isTrue);
    expect(taskOf(reload).running, isFalse);
    expect(buttonOf(tester, reload).onPressed, isNull);
    expect(buttonOf(tester, restart).onPressed, isNull);
    // Stop stays one click away
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
  });
}
