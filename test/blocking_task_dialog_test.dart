import 'dart:async';

import 'package:fide/services/blocking_task.dart';
import 'package:fide/widgets/blocking_task_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('blocks the app while its task runs, showing its steps, '
      'Cancel asking it to stop, until it ends', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (built) {
            context = built;
            return const Scaffold(body: Text('The app'));
          },
        ),
      ),
    );
    final done = Completer<String>();
    late BlockingTask task;

    final result = BlockingTaskDialog.run(
      context,
      title: 'Fix States',
      step: 'Analyzing the project…',
      run: (running) {
        task = running;
        return done.future;
      },
    );
    await tester.pump();
    expect(find.text('Fix States'), findsOneWidget);
    expect(find.text('Analyzing the project…'), findsOneWidget);

    task.report('Fixing a.dart (1 of 2)…');
    await tester.pump();
    expect(find.text('Fixing a.dart (1 of 2)…'), findsOneWidget);

    // Neither Escape nor a click on the scrim closes it
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(Offset.zero);
    await tester.pump();
    expect(find.byType(BlockingTaskDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(task.isCancelled, isTrue);
    expect(find.text(BlockingTaskDialog.cancellingStep), findsOneWidget);

    done.complete('stopped');
    expect(await result, 'stopped');
    await tester.pumpAndSettle();
    expect(find.byType(BlockingTaskDialog), findsNothing);
  });

  testWidgets('closes when its task fails, passing the failure on', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (built) {
            context = built;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = BlockingTaskDialog.run<void>(
      context,
      title: 'Split',
      step: 'Planning…',
      run: (_) async => throw StateError('broken'),
    );

    await expectLater(result, throwsStateError);
    await tester.pumpAndSettle();
    expect(find.byType(BlockingTaskDialog), findsNothing);
  });
}
