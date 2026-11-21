import 'dart:convert';
import 'dart:io';

import 'package:fide/models/arb_translation.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fake_chat_model.dart';
import 'localization_setup_test.dart' show FakeFlutterRunner;

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('fide_translate_'));
  tearDown(() => project.deleteSync(recursive: true));

  test('translates a batch in one request, keeping placeholders', () async {
    final ai = FakeChatModel(
      answer: (_) =>
          '<think>French</think>```json\n'
          '["Supprimer {name} ?", "Bonjour"]\n```',
    );
    final requests = ai.prompts;
    final runner = FakeFlutterRunner();
    final arbPath = p.join(project.path, 'app_fr.arb');
    File(arbPath).writeAsStringSync('{"@@locale": "fr"}');

    final result =
        await ArbTranslator(
          ai,
          const ProjectConfigReader(),
          L10nGenerator(runner),
        ).apply(project.path, [
          ArbTranslation(
            key: 'deleteMessage',
            source: 'Delete {name}?',
            language: 'French',
            arbPath: arbPath,
            description: 'Confirmation dialog title',
          ),
          ArbTranslation(
            key: 'hello',
            source: 'Hello {name}',
            language: 'French',
            arbPath: arbPath,
          ),
        ]);

    expect(result.rewritten, 1);
    expect(result.skipped, {ArbTranslator.lostPlaceholder: 1});
    expect(jsonDecode(File(arbPath).readAsStringSync()), {
      '@@locale': 'fr',
      'deleteMessage': 'Supprimer {name} ?',
    });
    expect(runner.commands, ['flutter gen-l10n']);
    // One request for the batch, the texts sent as a JSON list with their
    // keys and descriptions
    expect(
      requests.single,
      endsWith(
        jsonEncode([
          {
            'key': 'deleteMessage',
            'text': 'Delete {name}?',
            'description': 'Confirmation dialog title',
          },
          {'key': 'hello', 'text': 'Hello {name}'},
        ]),
      ),
    );
  });

  test('reads a reply in the shape of the request, by key', () async {
    // qwen3-coder answers a short batch so at times, out of order here
    final ai = FakeChatModel(
      answer: (_) =>
          '[{"key":"stop","text":"Detener"},'
          '{"key":"speaking","text":"El tutor está hablando…"}]',
    );
    final arbPath = p.join(project.path, 'app_es.arb');
    File(arbPath).writeAsStringSync('{"@@locale": "es"}');

    final result =
        await ArbTranslator(
          ai,
          const ProjectConfigReader(),
          L10nGenerator(FakeFlutterRunner()),
        ).apply(project.path, [
          for (final (key, source) in [
            ('speaking', 'The tutor is speaking…'),
            ('stop', 'Stop'),
          ])
            ArbTranslation(
              key: key,
              source: source,
              language: 'Spanish',
              arbPath: arbPath,
            ),
        ]);

    expect(result.rewritten, 2);
    expect(result.skipped, isEmpty);
    expect(jsonDecode(File(arbPath).readAsStringSync()), {
      '@@locale': 'es',
      'speaking': 'El tutor está hablando…',
      'stop': 'Detener',
    });
  });

  test('marks a translation the same as the template reviewed', () async {
    final ai = FakeChatModel(answer: (_) => '["Photos"]');
    final arbPath = p.join(project.path, 'app_fr.arb');
    File(arbPath).writeAsStringSync(
      '{"@@locale": "fr", "photos": "Photos", "@photos": {"type": "text"}}',
    );

    final result =
        await ArbTranslator(
          ai,
          const ProjectConfigReader(),
          L10nGenerator(FakeFlutterRunner()),
        ).apply(project.path, [
          ArbTranslation(
            key: 'photos',
            source: 'Photos',
            language: 'French',
            arbPath: arbPath,
          ),
        ]);

    expect(result.rewritten, 0);
    expect(result.skipped, {ArbTranslator.sameText: 1});
    expect(jsonDecode(File(arbPath).readAsStringSync()), {
      '@@locale': 'fr',
      'photos': 'Photos',
      '@photos': {
        'type': 'text',
        'description': ArbTranslator.reviewedDescription,
      },
    });
  });

  test('stops at the batch its token cancels', () async {
    final ai = FakeChatModel(answer: (_) => '["Bonjour"]');
    final arbPath = p.join(project.path, 'app_fr.arb');
    File(arbPath).writeAsStringSync('{"@@locale": "fr"}');

    await expectLater(
      ArbTranslator(
        ai,
        const ProjectConfigReader(),
        L10nGenerator(FakeFlutterRunner()),
      ).apply(project.path, [
        ArbTranslation(
          key: 'hello',
          source: 'Hello',
          language: 'French',
          arbPath: arbPath,
        ),
      ], cancel: AiCancelToken()..cancel()),
      throwsA(
        isA<Exception>().having((e) => '$e', 'message', contains('Stopped')),
      ),
    );
    expect(ai.prompts, isEmpty);
  });
}
