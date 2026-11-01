import 'dart:convert';
import 'dart:io';

import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An SDK whose versions can't be detected, so no tool runs.
class _NoSdk extends FlutterSdk {
  const _NoSdk();

  @override
  Future<({String? flutter, String? dart})?> versions() async => null;
}

void main() {
  AIService serviceAnswering(http.Response response) =>
      AIService(const _NoSdk(), MockClient((_) async => response));

  test('returns the model response text', () async {
    final service = serviceAnswering(
      http.Response(jsonEncode({'response': 'use const'}), HttpStatus.ok),
    );

    expect(await service.getCodeSuggestion('tip?', ''), 'use const');
  });

  test('an error status throws AiServiceException', () async {
    final service = serviceAnswering(
      http.Response('', HttpStatus.internalServerError),
    );

    expect(
      service.getCodeSuggestion('tip?', ''),
      throwsA(isA<AiServiceException>()),
    );
  });

  test('an unreachable server throws AiServiceException', () async {
    final service = AIService(
      const _NoSdk(),
      MockClient((_) => throw const SocketException('refused')),
    );

    expect(
      service.explainCode('void main() {}'),
      throwsA(isA<AiServiceException>()),
    );
  });

  test('cancel aborts the request in flight, not later ones', () async {
    var isFirst = true;
    final service = AIService(
      const _NoSdk(),
      MockClient.streaming((request, _) async {
        if (isFirst) {
          await (request as http.Abortable).abortTrigger;
          isFirst = false;
          throw http.RequestAbortedException(request.url);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'response': 'ok'}))),
          HttpStatus.ok,
        );
      }),
    );

    final pending = service.getCodeSuggestion('tip?', '');
    await pumpEventQueue();
    service.cancel();

    await expectLater(pending, throwsA(isA<AiCancelledException>()));
    expect(await service.getCodeSuggestion('tip?', ''), 'ok');
  });

  test('fix build sends the build errors to the model', () async {
    late String prompt;
    final service = AIService(
      const _NoSdk(),
      MockClient((request) async {
        prompt = jsonDecode(request.body)['prompt'] as String;
        return http.Response(jsonEncode({'response': 'fixed'}), HttpStatus.ok);
      }),
    );

    final response = await service.respond(
      AiAction.fixBuild,
      '',
      "lib/main.dart:3:1: Error: Expected ';'",
    );

    expect(response, 'fixed');
    expect(prompt, contains("Expected ';'"));
  });

  test('generateProject falls back to a basic main.dart', () async {
    final service = serviceAnswering(
      http.Response(jsonEncode({'response': 'no code here'}), HttpStatus.ok),
    );

    final files = await service.generateProject('demo', 'A demo');

    expect(files['lib/main.dart'], contains('void main()'));
    expect(files['pubspec.yaml'], contains('name: demo'));
  });

  /// A service whose Ollama lists [models], of which [toolModels] can call
  /// tools and [thinkingModels] think, and records the model each generate
  /// request names, and its whole body in [bodies].
  AIService serviceWithModels(
    List<String> models,
    Set<String> toolModels,
    List<String> requested, {
    Set<String> thinkingModels = const {},
    List<Map<String, dynamic>>? bodies,
  }) => AIService(
    const _NoSdk(),
    MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'models': [
              for (final name in models) {'name': name},
            ],
          }),
          HttpStatus.ok,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final model = body['model'] as String;
      if (request.url.path == '/api/show') {
        return http.Response(
          jsonEncode({
            'capabilities': [
              'completion',
              if (toolModels.contains(model)) 'tools',
              if (thinkingModels.contains(model)) 'thinking',
            ],
          }),
          HttpStatus.ok,
        );
      }
      requested.add(model);
      bodies?.add(body);
      return http.Response(jsonEncode({'response': 'ok'}), HttpStatus.ok);
    }),
  );

  test('uses the preferred model when it is downloaded', () async {
    final requested = <String>[];
    final service = serviceWithModels(
      ['codellama:latest', '${OllamaInstaller.model}:latest'],
      {'${OllamaInstaller.model}:latest'},
      requested,
    );

    await service.getCodeSuggestion('tip?', '');

    expect(requested, ['${OllamaInstaller.model}:latest']);
    expect(service.isFallbackModel, isFalse);
    expect(service.supportsTools, isTrue);
  });

  test('falls back to a downloaded model that can call tools', () async {
    final requested = <String>[];
    final service = serviceWithModels(
      ['codellama:latest', 'qwen3:8b'],
      {'qwen3:8b'},
      requested,
    );

    await service.getCodeSuggestion('tip?', '');

    expect(requested, ['qwen3:8b']);
    expect(service.isFallbackModel, isTrue);
  });

  test('falls back to any model when none can call tools', () async {
    final service = serviceWithModels(['codellama:latest'], {}, []);

    expect(await service.resolveModel(), 'codellama:latest');
    expect(service.supportsTools, isFalse);
  });

  test('thinking models think only for reviews', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = serviceWithModels(
      ['qwen3:8b'],
      {'qwen3:8b'},
      [],
      thinkingModels: {'qwen3:8b'},
      bodies: bodies,
    );

    await service.getCodeSuggestion('tip?', '');
    await service.reviewCode('Review.', '', 'findings');

    expect([for (final body in bodies) body['think']], [false, true]);
    expect(bodies.first['keep_alive'], isPositive);
    // One context size for every request, so Ollama never reloads
    expect({
      for (final body in bodies) jsonEncode(body['options']),
    }, hasLength(1));
  });

  test('models without thinking get no think option', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = serviceWithModels(
      ['codellama:latest'],
      {},
      [],
      bodies: bodies,
    );

    await service.getCodeSuggestion('tip?', '');

    expect(bodies.single.containsKey('think'), isFalse);
  });

  test('commit message keeps the first line without quotes', () async {
    final service = serviceAnswering(
      http.Response(
        jsonEncode({'response': '\n"Add login screen"\nIt adds a screen.'}),
        HttpStatus.ok,
      ),
    );

    expect(await service.commitMessage('diff'), 'Add login screen');
  });
}
