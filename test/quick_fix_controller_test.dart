import 'dart:io';

import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/quick_fix_controller.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A handler confirming once, then reporting [summary].
class _ConfirmingHandler implements QuickFixHandler {
  const _ConfirmingHandler(this.summary);

  final String summary;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    if (!await request.confirm('Go?')) return null;
    request.onProgress?.call('Working…');
    return (summary: summary, changedFiles: const <String>[]);
  }
}

void main() {
  late Directory project;
  late ProviderContainer container;
  late List<(String, StatusTone)> notices;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_quick_fix_');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${project.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('/// A.\nclass A {}\n');
    notices = [];
    container = ProviderContainer(
      overrides: [
        quickFixRunnerProvider.overrideWith(
          (ref) => QuickFixRunner(
            review: const CodeReview(),
            strings: ref.read(stringFixerProvider),
            handlers: const {
              QuickFix.sortMembers: _ConfirmingHandler('Sorted'),
              QuickFix.translateKeys: _ConfirmingHandler('Translated'),
            },
          ),
        ),
      ],
    );
    container.read(currentProjectPathProvider.notifier).state = project.path;
  });

  tearDown(() {
    container.dispose();
    project.deleteSync(recursive: true);
  });

  /// Applies [fix], confirming it, recording the messages in [notices].
  Future<void> apply(QuickFix fix) => container
      .read(quickFixControllerProvider)
      .apply(
        fix,
        confirm: (_, _) async => true,
        notify: (message, tone) => notices.add((message, tone)),
      );

  test('reports a fix without the model in messages', () async {
    await apply(QuickFix.sortMembers);

    expect(notices, [
      ('${QuickFix.sortMembers.label}…', StatusTone.info),
      ('Sorted', StatusTone.success),
    ]);
  });

  test('runs a fix asking the model as a task in the AI panel', () async {
    await apply(QuickFix.translateKeys);

    final chat = container.read(aiChatProvider);
    expect(notices, isEmpty);
    expect(
      [for (final message in chat.messages) message.content],
      [QuickFix.translateKeys.label, 'Working…', 'Translated'],
    );
    expect(chat.isBusy, isFalse);
  });

  test('a fix asking the model waits for the busy AI', () async {
    container.read(aiChatProvider.notifier).beginTask('Explain');

    await apply(QuickFix.translateKeys);

    expect(notices.single.$2, StatusTone.error);
  });
}
