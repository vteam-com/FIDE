import 'dart:async';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/widget_services/command_action_list.dart';
import 'package:fide/widget_services/command_output.dart';
import 'package:fide/widgets/action_list.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const String _id = 'run';
const String _log = 'log';

void main() {
  /// Shows a [CommandActionList] with one action and the [CommandOutput]
  /// of its log, then starts a run of that action whose output the
  /// returned sink receives; completing the returned exit ends the run.
  Future<(BuildOutput, Completer<int>)> start(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  CommandActionList(
                    actions: [
                      PanelAction(
                        id: _id,
                        title: 'Run',
                        description: 'Runs the app',
                        details: 'Runs the app',
                        icon: Icons.play_arrow,
                        onRun: () {},
                      ),
                    ],
                  ),
                  const CommandOutput(logKey: _log),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final exit = Completer<int>();
    late BuildOutput output;
    unawaited(
      container
          .read(commandRunnerProvider.notifier)
          .run(
            _id,
            logKey: _log,
            startMessages: const ['start'],
            command: (o) {
              output = o;
              return exit.future;
            },
            successMessage: 'ok',
            failureMessage: (code) => 'failed $code',
            errorPrefix: 'error: ',
          ),
    );
    await tester.pump();
    return (output, exit);
  }

  /// Ends the run [exit] completes and waits out its status reset.
  Future<void> finish(WidgetTester tester, Completer<int> exit) async {
    exit.complete(0);
    await tester.pump();
    await tester.pump(AppDuration.buildStatusResetDelay);
  }

  testWidgets('log lines show without rebuilding the action buttons', (
    tester,
  ) async {
    final (output, exit) = await start(tester);
    ActionList actionList() => tester.widget(find.byType(ActionList));
    final before = actionList();

    output.onOutput('compiling');
    await tester.pump(AppDuration.outputLogPublish);

    expect(find.textContaining('compiling', findRichText: true), findsOne);
    expect(identical(actionList(), before), isTrue);

    await finish(tester, exit);
    expect(identical(actionList(), before), isFalse);
  });
}
