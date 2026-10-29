import 'dart:convert';
import 'dart:io';

import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/flutter_sdk.dart';
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
}
