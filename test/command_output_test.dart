import 'dart:async';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/widget_services/command_action_list.dart';
import 'package:fide/widget_services/command_output.dart';
import 'package:fide/widgets/action_list.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_chat_model.dart';

const String _id = 'run';
const String _log = 'log';

void main() {
  /// Shows a [CommandActionList] with one action and the [CommandOutput]
  /// of its log, then starts a run of that action, reporting its errors
  /// for Fix Build when [reportsBuildErrors], whose output the returned
  /// sink receives; completing the returned exit ends the run. The
  /// returned container answers AI requests with [model].
  Future<(ProviderContainer, BuildOutput, Completer<int>)> start(
    WidgetTester tester, {
    bool reportsBuildErrors = false,
    FakeChatModel? model,
  }) async {
    final container = ProviderContainer(
      overrides: [
        chatModelProvider.overrideWithValue(model ?? FakeChatModel()),
      ],
    );
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
            reportsBuildErrors: reportsBuildErrors,
          ),
    );
    await tester.pump();
    return (container, output, exit);
  }

  /// Ends the run [exit] completes with [exitCode] and waits out its
  /// status reset.
  Future<void> finish(
    WidgetTester tester,
    Completer<int> exit, {
    int exitCode = 0,
  }) async {
    exit.complete(exitCode);
    await tester.pump();
    await tester.pump(AppDuration.buildStatusResetDelay);
  }

  testWidgets('log lines show without rebuilding the action buttons', (
    tester,
  ) async {
    final (_, output, exit) = await start(tester);
    ActionList actionList() => tester.widget(find.byType(ActionList));
    final before = actionList();

    output.onOutput('compiling');
    await tester.pump(AppDuration.outputLogPublish);

    expect(find.textContaining('compiling', findRichText: true), findsOne);
    expect(identical(actionList(), before), isTrue);

    await finish(tester, exit);
    expect(identical(actionList(), before), isFalse);
  });

  /// The Errors section's Fix with AI button.
  final fixWithAi = find.byTooltip('Fix with AI');

  testWidgets('the errors of a failed build offer to fix it with AI', (
    tester,
  ) async {
    const error = 'lib/main.dart:3:5: Error: Expected ";"';
    final model = FakeChatModel(answer: (_) => 'Added the semicolon.');
    final (container, output, exit) = await start(
      tester,
      reportsBuildErrors: true,
      model: model,
    );
    output.onError(error);
    await finish(tester, exit, exitCode: 1);

    await tester.tap(fixWithAi.hitTestable());
    await tester.pump();

    final chat = container.read(aiChatProvider);
    expect(chat.action, AiAction.fixBuild);
    expect(chat.messages.first.content, AiAction.fixBuild.label);
    expect(model.prompts.single, contains(error));
  });

  testWidgets('errors of a run that is no build offer no AI fix', (
    tester,
  ) async {
    final (_, output, exit) = await start(tester);
    output.onError('1 test failed');
    await finish(tester, exit, exitCode: 1);

    expect(find.text('Errors'), findsOne);
    expect(fixWithAi, findsNothing);
  });

  testWidgets('a build that succeeds again takes the AI fix away', (
    tester,
  ) async {
    final (container, output, exit) = await start(
      tester,
      reportsBuildErrors: true,
    );
    output.onError('Error: Expected ";"');
    await finish(tester, exit, exitCode: 1);
    expect(fixWithAi, findsWidgets);

    container.read(lastBuildErrorsProvider.notifier).state = '';
    await tester.pump();

    expect(fixWithAi, findsNothing);
  });
}
