import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget button) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: button)));

  final ring = find.byType(CircularProgressIndicator);

  testWidgets('idle, it runs the task, without a ring', (tester) async {
    var runs = 0;
    await pump(
      tester,
      TaskButton(icon: Icons.play_arrow, tooltip: 'Run', onRun: () => runs++),
    );

    await tester.tap(find.byTooltip('Run'));

    expect(runs, 1);
    expect(ring, findsNothing);
  });

  testWidgets('running, a ring spins around Stop', (tester) async {
    var stops = 0;
    await pump(
      tester,
      TaskButton(
        icon: Icons.play_arrow,
        tooltip: 'Run',
        running: true,
        onRun: () {},
        onStop: () => stops++,
      ),
    );

    await tester.tap(find.byTooltip('Stop (Esc)'));

    expect(stops, 1);
    expect(ring, findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('live, Stop shows without the ring', (tester) async {
    await pump(
      tester,
      TaskButton(
        icon: Icons.play_arrow,
        tooltip: 'Run',
        running: true,
        live: true,
        onRun: () {},
        onStop: () {},
      ),
    );

    expect(find.byTooltip('Stop (Esc)'), findsOneWidget);
    expect(ring, findsNothing);
  });

  testWidgets('a busy Refresh, which can not stop, spins disabled', (
    tester,
  ) async {
    var runs = 0;
    await pump(tester, RefreshButton(busy: true, onPressed: () => runs++));

    await tester.tap(find.byIcon(Icons.refresh), warnIfMissed: false);

    expect(runs, 0);
    expect(ring, findsOneWidget);
    expect(find.byTooltip('Stop (Esc)'), findsNothing);
  });
}
