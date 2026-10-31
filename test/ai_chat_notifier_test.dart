import 'dart:convert';
import 'dart:io';

import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late ProviderContainer container;

  setUp(() {
    final client = MockClient((request) async {
      // Model lookups: no model listed, so requests keep the default
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'models': []}), HttpStatus.ok);
      }
      return http.Response(
        jsonEncode({'response': 'It prints a greeting.'}),
        HttpStatus.ok,
      );
    });
    container = ProviderContainer(
      overrides: [
        aiServiceProvider.overrideWithValue(AIService(const _NoSdk(), client)),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('keeps the conversation outside the panel', () async {
    await container
        .read(aiChatProvider.notifier)
        .send('What does this do?', action: AiAction.explain);

    final chat = container.read(aiChatProvider);
    expect(
      [for (final message in chat.messages) message.content],
      ['What does this do?', 'It prints a greeting.'],
    );
    expect(chat.isBusy, isFalse);
    expect(chat.action, AiAction.explain);
  });

  test('shows a task with its progress until it ends', () {
    final chat = container.read(aiChatProvider.notifier);

    chat.beginTask('Translate with AI');
    chat.addReply('Translating 1–20 of 22 keys into French…', isProgress: true);
    expect(container.read(aiChatProvider).isBusy, isTrue);
    chat.endTask('Translated 22 strings in 1 files');

    final state = container.read(aiChatProvider);
    expect(state.isBusy, isFalse);
    expect(state.messages.first.isUser, isTrue);
    expect(state.messages.last.content, 'Translated 22 strings in 1 files');
  });

  test('stops a pending task', () {
    final chat = container.read(aiChatProvider.notifier)
      ..beginTask('Translate with AI');

    chat.cancel();

    final state = container.read(aiChatProvider);
    expect(state.isBusy, isFalse);
    expect(state.messages.last.content, '⏹ Stopped.');
  });
}
