import 'dart:io';

import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/quick_fix_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

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

/// Reports every translation as written without asking a model.
class _FakeTranslator extends ArbTranslator {
  _FakeTranslator()
    : super(
        FakeChatModel(),
        const ProjectConfigReader(),
        const L10nGenerator(ProcessRunner()),
      );

  final List<ArbTranslation> applied = [];

  @override
  Future<StringRewrite> apply(
    String projectPath,
    List<ArbTranslation> translations, {
    AiCancelToken? cancel,
    void Function(String)? onProgress,
  }) async {
    applied.addAll(translations);
    return StringRewrite(
      action: 'Translated',
      rewritten: translations.length,
      changedFiles: const [],
      skipped: const {},
    );
  }
}

void main() {
  late Directory project;
  late ProviderContainer container;
  late List<(String, StatusTone)> notices;
  late _FakeTranslator translator;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_quick_fix_');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${project.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('/// A.\nclass A {}\n');
    notices = [];
    translator = _FakeTranslator();
    container = ProviderContainer(
      overrides: [
        arbTranslatorProvider.overrideWithValue(translator),
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

  test('translates one key as a task in the AI panel', () async {
    const translation = ArbTranslation(
      key: 'hi',
      source: 'Hello',
      language: 'fr',
      arbPath: '/p/lib/l10n/app_fr.arb',
    );

    await container.read(quickFixControllerProvider).translate([
      translation,
    ], notify: (message, tone) => notices.add((message, tone)));

    final chat = container.read(aiChatProvider);
    expect(translator.applied, [translation]);
    expect(notices, isEmpty);
    expect(chat.messages.first.content, QuickFix.translateKeys.label);
    expect(chat.isBusy, isFalse);
  });

  test('translates a new locale once the user accepts', () async {
    const translations = [
      ArbTranslation(
        key: 'hi',
        source: 'Hello',
        language: 'German',
        arbPath: '/p/lib/l10n/app_de.arb',
      ),
    ];
    final asked = <String>[];

    for (final accept in [false, true]) {
      await container
          .read(quickFixControllerProvider)
          .translate(
            translations,
            confirm: (fix, message) async {
              asked.add(message);
              return accept;
            },
            notify: (message, tone) => notices.add((message, tone)),
          );
    }

    expect(asked, List.filled(2, ArbTranslator.describe(translations)));
    expect(asked.first, contains('1 key into German'));
    expect(translator.applied, translations);
  });

  test('a fix asking the model waits for the busy AI', () async {
    container.read(aiChatProvider.notifier).beginTask('Explain');

    await apply(QuickFix.translateKeys);

    expect(notices.single.$2, StatusTone.error);
  });
}
