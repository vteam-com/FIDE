import 'dart:convert';
import 'dart:io';

import 'package:fide/models/arb_translation.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/arb_translator.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'localization_service_test.dart' show FakeFlutterRunner;

/// An SDK whose versions can't be detected, so no tool runs.
class _NoSdk extends FlutterSdk {
  const _NoSdk();

  @override
  Future<({String? flutter, String? dart})?> versions() async => null;
}

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('fide_translate_'));
  tearDown(() => project.deleteSync(recursive: true));

  test('translates a batch in one request, keeping placeholders', () async {
    final requests = <String>[];
    final ai = AIService(
      const _NoSdk(),
      MockClient((request) async {
        requests.add(jsonDecode(request.body)['prompt'] as String);
        const reply =
            '<think>French</think>```json\n'
            '["Supprimer {name} ?", "Bonjour"]\n```';
        return http.Response(jsonEncode({'response': reply}), HttpStatus.ok);
      }),
    );
    final runner = FakeFlutterRunner();
    final arbPath = p.join(project.path, 'app_fr.arb');
    File(arbPath).writeAsStringSync('{"@@locale": "fr"}');

    final result = await ArbTranslator(ai, LocalizationService(runner)).apply(
      project.path,
      [
        for (final MapEntry(:key, :value) in {
          'deleteMessage': 'Delete {name}?',
          'hello': 'Hello {name}',
        }.entries)
          ArbTranslation(
            key: key,
            source: value,
            language: 'French',
            arbPath: arbPath,
          ),
      ],
    );

    expect(result.rewritten, 1);
    expect(result.skipped, {ArbTranslator.lostPlaceholder: 1});
    expect(jsonDecode(File(arbPath).readAsStringSync()), {
      '@@locale': 'fr',
      'deleteMessage': 'Supprimer {name} ?',
    });
    expect(runner.commands, ['flutter gen-l10n']);
    // One request for the batch, the texts sent as a JSON list
    expect(requests.single, endsWith('["Delete {name}?","Hello {name}"]'));
  });

  test('marks a translation the same as the template reviewed', () async {
    final ai = AIService(
      const _NoSdk(),
      MockClient(
        (request) async => http.Response(
          jsonEncode({'response': '["Photos"]'}),
          HttpStatus.ok,
        ),
      ),
    );
    final arbPath = p.join(project.path, 'app_fr.arb');
    File(arbPath).writeAsStringSync(
      '{"@@locale": "fr", "photos": "Photos", "@photos": {"type": "text"}}',
    );

    final result =
        await ArbTranslator(ai, LocalizationService(FakeFlutterRunner())).apply(
          project.path,
          [
            ArbTranslation(
              key: 'photos',
              source: 'Photos',
              language: 'French',
              arbPath: arbPath,
            ),
          ],
        );

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
}
