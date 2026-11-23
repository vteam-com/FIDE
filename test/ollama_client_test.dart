import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/local_model.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tag of the model the client prefers by default.
final String _preferred = LocalModel.defaultModel.tag;

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

  test('a model answering too late is aborted, and says so', () async {
    var aborted = false;
    final client = OllamaClient(
      MockClient.streaming((request, _) async {
        if (request.method == 'GET') return reply('');
        // Answers only once aborted, as a stalled model never does
        await (request as http.Abortable).abortTrigger;
        aborted = true;
        throw http.RequestAbortedException(request.url);
      }),
    );

    await expectLater(
      client.generate('tip?', const Duration(milliseconds: 1)),
      throwsA(
        isA<AiServiceException>().having(
          (e) => e.toString(),
          'message',
          contains('no answer within'),
        ),
      ),
    );
    expect(aborted, isTrue);
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
      ['codellama:latest', _preferred],
      {_preferred},
      requested,
    );

    await client.generate('tip?', timeout);

    expect(requested, [_preferred]);
    expect(client.isFallbackModel, isFalse);
    expect(client.supportsTools, isTrue);
  });

  test('another model picked is resolved on the next request', () async {
    final requested = <String>[];
    final client = clientWithModels(
      [_preferred, LocalModel.qwenCoder.tag],
      {_preferred, LocalModel.qwenCoder.tag},
      requested,
    );
    await client.generate('tip?', timeout);

    client.preferred = LocalModel.qwenCoder.tag;
    await client.generate('tip?', timeout);

    expect(requested, [_preferred, LocalModel.qwenCoder.tag]);
    expect(client.downloaded, {_preferred, LocalModel.qwenCoder.tag});
    expect(client.isFallbackModel, isFalse);
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

  /// A streamed Ollama answer of one JSON object per line.
  http.StreamedResponse streamed(List<Map<String, Object>> chunks) =>
      http.StreamedResponse(
        Stream.fromIterable([
          for (final chunk in chunks) utf8.encode('${jsonEncode(chunk)}\n'),
        ]),
        HttpStatus.ok,
      );

  test('streams the reply, its text as it grows', () async {
    final client = OllamaClient(
      MockClient.streaming((request, _) async {
        if (request.method == 'GET') return reply('');
        return streamed([
          {
            'message': {'role': 'assistant', 'content': 'Let me '},
          },
          {
            'message': {'role': 'assistant', 'content': 'look.'},
          },
          {
            'message': {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'id': 'call_1',
                  'function': {
                    'name': 'read_file',
                    'arguments': {'path': 'lib/main.dart'},
                  },
                },
              ],
            },
            'done': true,
          },
        ]);
      }),
    );
    final texts = <String>[];

    final message = await client.chat([], [], onText: texts.add);

    expect(texts, ['Let me', 'Let me look.']);
    expect(message['content'], 'Let me look.');
    expect((message['tool_calls'] as List).single['id'], 'call_1');
  });

  test('recovers a tool call the model wrote as text', () async {
    // qwen3-coder's call without its opening tag, which Ollama leaves as
    // text
    final client = clientAnswering(
      http.Response(
        jsonEncode({
          'message': {
            'role': 'assistant',
            'content':
                'Let me check the file:\n\n<function=read_file>\n'
                '<parameter=path>\nlib/main.dart\n</parameter>\n</function>\n'
                '</tool_call>',
          },
        }),
        HttpStatus.ok,
      ),
    );

    final message = await client.chat([], []);

    expect(message['content'], 'Let me check the file:');
    final call = (message['tool_calls'] as List).single as Map;
    expect(call['function'], {
      'name': 'read_file',
      'arguments': {'path': 'lib/main.dart'},
    });
  });

  test(
    'asks again when Ollama fails on a malformed tool call, saying so',
    () async {
      final sent = <List<Object?>>[];
      final client = OllamaClient(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{}', HttpStatus.ok);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sent.add(body['messages'] as List<Object?>);
          if (sent.length == 1) {
            return http.Response(
              jsonEncode({
                'error': 'XML syntax error on line 3: unexpected EOF',
              }),
              HttpStatus.internalServerError,
            );
          }
          return http.Response(
            jsonEncode({
              'message': {'role': 'assistant', 'content': 'done'},
            }),
            HttpStatus.ok,
          );
        }),
      );
      final messages = [
        {'role': 'user', 'content': 'Fix main'},
      ];

      expect((await client.chat(messages, []))['content'], 'done');

      // The same request would write the same broken call
      expect(sent.first, messages);
      expect(sent.last, hasLength(messages.length + 1));
      expect((sent.last.last as Map)['content'], contains('</function>'));
    },
  );

  test(
    'warming up loads the model with no prompt, as requests set it',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = clientWithModels(
        [_preferred],
        {_preferred},
        [],
        bodies: bodies,
      );

      await Future.wait([client.warmUp(), client.warmUp()]);
      await client.generate('tip?', timeout);

      // Both calls share one load, with the options every request has
      final load = bodies.first;
      expect(bodies, hasLength(2));
      expect(load.containsKey('prompt'), isFalse);
      expect(jsonEncode(load['options']), jsonEncode(bodies.last['options']));
      expect(load['keep_alive'], bodies.last['keep_alive']);
    },
  );

  test('stopping or timing out mid-answer says so, not a raw error', () async {
    /// A client streaming one word, then nothing until aborted.
    OllamaClient stalling() => OllamaClient(
      MockClient.streaming((request, _) async {
        if (request.method == 'GET') return reply('');
        final aborted = (request as http.Abortable).abortTrigger!;
        final words = StreamController<List<int>>();
        words.add(utf8.encode('${jsonEncode({'response': 'Hel'})}\n'));
        unawaited(
          aborted.then((_) {
            words.addError(http.RequestAbortedException(request.url));
            words.close();
          }),
        );
        return http.StreamedResponse(words.stream, HttpStatus.ok);
      }),
    );
    final cancel = AiCancelToken();
    final texts = <String>[];

    final stopped = stalling().generate(
      'tip?',
      timeout,
      cancel: cancel,
      onText: (text) {
        texts.add(text);
        cancel.cancel();
      },
    );

    await expectLater(stopped, throwsA(isA<AiCancelledException>()));
    expect(texts, ['Hel']);
    await expectLater(
      stalling().generate('tip?', const Duration(milliseconds: 1)),
      throwsA(
        isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('no answer within'),
        ),
      ),
    );
  });
}
