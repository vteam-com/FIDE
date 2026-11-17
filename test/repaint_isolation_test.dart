import 'package:fide/constants/constants.dart';
import 'package:fide/widget_services/panel_island.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Counts how often it paints, standing for a panel's content such as the
/// editor text.
class _CountingPainter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => false;
}

/// Frames pumped while the indicator animates.
const int _frames = 60;

/// One frame at 60 frames per second.
const Duration _frame = Duration(milliseconds: 16);

/// How often a panel beside an island showing [indicator] repaints over
/// [_frames] frames.
Future<int> _siblingPaints(WidgetTester tester, Widget indicator) async {
  final painter = _CountingPainter();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: PanelIsland(
                  child: CustomPaint(painter: painter, child: const SizedBox()),
                ),
              ),
              Expanded(child: PanelIsland(child: indicator)),
            ],
          ),
        ),
      ),
    ),
  );
  painter.paints = 0;
  for (var i = 0; i < _frames; i++) {
    await tester.pump(_frame);
  }
  return painter.paints;
}

void main() {
  testWidgets('an animating BusyBar leaves the panel beside it unpainted', (
    tester,
  ) async {
    expect(await _siblingPaints(tester, const BusyBar()), 0);
  });

  testWidgets('a spinning InlineSpinner leaves the panel beside it unpainted', (
    tester,
  ) async {
    expect(await _siblingPaints(tester, const InlineSpinner()), 0);
  });

  testWidgets(
    'a running TaskButton ring leaves the panel beside it unpainted',
    (tester) async {
      final button = TaskButton(
        icon: Icons.play_arrow,
        tooltip: 'Run',
        onRun: () {},
        running: true,
      );
      expect(await _siblingPaints(tester, button), 0);
    },
  );

  testWidgets('the spinner repaints alone, not the panel around it', (
    tester,
  ) async {
    final painter = _CountingPainter();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CustomPaint(
                painter: painter,
                child: const SizedBox.square(dimension: AppIconSize.large),
              ),
              const BusyBar.over(busy: true, child: SizedBox.shrink()),
              const InlineSpinner.small(),
            ],
          ),
        ),
      ),
    );
    painter.paints = 0;
    for (var i = 0; i < _frames; i++) {
      await tester.pump(_frame);
    }
    expect(painter.paints, 0);
  });
}
