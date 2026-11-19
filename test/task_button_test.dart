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

  testWidgets('prominent, it is filled with the accent color', (tester) async {
    /// The fill of the button showing [icon].
    Color? fillOf(IconData icon) => tester
        .widget<Material>(
          find
              .ancestor(of: find.byIcon(icon), matching: find.byType(Material))
              .first,
        )
        .color;

    await pump(
      tester,
      Row(
        children: [
          TaskButton(icon: Icons.play_arrow, tooltip: 'Run', onRun: () {}),
          TaskButton(
            icon: Icons.system_update_alt,
            tooltip: 'Update',
            onRun: () {},
            prominent: true,
          ),
        ],
      ),
    );
    final accent = Theme.of(tester.element(find.byType(Row)))
        .colorScheme
        .primary;

    expect(fillOf(Icons.system_update_alt), accent);
    expect(fillOf(Icons.play_arrow), isNot(accent));
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
