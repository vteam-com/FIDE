import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const timeout = AppDuration.aiSuggestionTimeout;

  OllamaClient clientAnswering(http.Response response) =>
      OllamaClient(MockClient((_) async => response));

  /// A streamed Ollama reply with [text].
  http.StreamedResponse reply(String text) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode({'response': text}))),
    HttpStatus.ok,
  );

  test('returns the model response text', () async {
    final client = clientAnswering(
      http.Response(jsonEncode({'response': 'use const'}), HttpStatus.ok),
    );

    expect(await client.generate('tip?', timeout), 'use const');
  });

  test('an error status throws AiServiceException', () async {
    final client = clientAnswering(
      http.Response('', HttpStatus.internalServerError),
    );

    expect(
      client.generate('tip?', timeout),
      throwsA(isA<AiServiceException>()),
    );
  });

  test('an unreachable server throws AiServiceException', () async {
    final client = OllamaClient(
      MockClient((_) => throw const SocketException('refused')),
    );

    expect(
      client.generate('void main() {}', timeout),
      throwsA(isA<AiServiceException>()),
    );
  });

  test('a token aborts its own requests, not the others', () async {
    final release = Completer<void>();
    final client = OllamaClient(
      MockClient.streaming((request, _) async {
        if (request.method == 'GET') return reply('');
        final aborted = (request as http.Abortable).abortTrigger;
        final isAborted = await Future.any([
          if (aborted != null) aborted.then((_) => true),
          release.future.then((_) => false),
        ]);
        if (isAborted) throw http.RequestAbortedException(request.url);
        return reply('ok');
      }),
    );
    final chatToken = AiCancelToken();

    final chatReply = client.generate('tip?', timeout, cancel: chatToken);
    final commitMessage = client.generate(
      'commit?',
      timeout,
      cancel: AiCancelToken(),
    );
    await pumpEventQueue();
    chatToken.cancel();

    await expectLater(chatReply, throwsA(isA<AiCancelledException>()));
    release.complete();
    expect(await commitMessage, 'ok');
    // A cancelled token stops its later requests before they are sent
    await expectLater(
      client.generate('again?', timeout, cancel: chatToken),
      throwsA(isA<AiCancelledException>()),
    );
    expect(await client.generate('tip?', timeout), 'ok');
  });

  /// A client whose Ollama lists [models], of which [toolModels] can call
  /// tools and [thinkingModels] think, and records the model each generate
  /// request names, and its whole body in [bodies].
  OllamaClient clientWithModels(
    List<String> models,
    Set<String> toolModels,
    List<String> requested, {
    Set<String> thinkingModels = const {},
    List<Map<String, dynamic>>? bodies,
  }) => OllamaClient(
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
    final client = clientWithModels(
      ['codellama:latest', '${AiModel.ollama}:latest'],
      {'${AiModel.ollama}:latest'},
      requested,
    );

    await client.generate('tip?', timeout);

    expect(requested, ['${AiModel.ollama}:latest']);
    expect(client.isFallbackModel, isFalse);
    expect(client.supportsTools, isTrue);
  });

  test('falls back to a downloaded model that can call tools', () async {
    final requested = <String>[];
    final client = clientWithModels(
      ['codellama:latest', 'qwen3:8b'],
      {'qwen3:8b'},
      requested,
    );

    await client.generate('tip?', timeout);

    expect(requested, ['qwen3:8b']);
    expect(client.isFallbackModel, isTrue);
  });

  test('falls back to any model when none can call tools', () async {
    final client = clientWithModels(['codellama:latest'], {}, []);

    expect(await client.resolveModel(), 'codellama:latest');
    expect(client.supportsTools, isFalse);
  });

  test('thinking models think only when asked', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = clientWithModels(
      ['qwen3:8b'],
      {'qwen3:8b'},
      [],
      thinkingModels: {'qwen3:8b'},
      bodies: bodies,
    );

    await client.generate('tip?', timeout);
    await client.generate('Review.', timeout, think: true);

    expect([for (final body in bodies) body['think']], [false, true]);
    expect(bodies.first['keep_alive'], isPositive);
    // One context size for every request, so Ollama never reloads
    expect({
      for (final body in bodies) jsonEncode(body['options']),
    }, hasLength(1));
  });

  test('models without thinking get no think option', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = clientWithModels(
      ['codellama:latest'],
      {},
      [],
      bodies: bodies,
    );

    await client.generate('tip?', timeout);

    expect(bodies.single.containsKey('think'), isFalse);
  });

  test('chat returns the reply message', () async {
    final client = clientAnswering(
      http.Response(
        jsonEncode({
          'message': {'role': 'assistant', 'content': 'done'},
        }),
        HttpStatus.ok,
      ),
    );

    expect(await client.chat([], []), {'role': 'assistant', 'content': 'done'});
  });
}
