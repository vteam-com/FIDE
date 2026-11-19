import 'dart:async';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ai_panel_busy_provider.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

void main() {
  late ProviderContainer container;
  late FakeChatModel model;

  setUp(() {
    model = FakeChatModel(answer: (_) => 'It prints a greeting.');
    container = ProviderContainer(
      overrides: [chatModelProvider.overrideWithValue(model)],
    );
  });

  tearDown(() => container.dispose());

  test('keeps the conversation outside the panel', () async {
    await container
        .read(aiChatProvider.notifier)
        .send('What does this do?', action: AiAction.ask);

    final chat = container.read(aiChatProvider);
    expect(
      [for (final message in chat.messages) message.content],
      ['What does this do?', 'It prints a greeting.'],
    );
    expect(chat.isBusy, isFalse);
    expect(chat.action, AiAction.ask);
    expect(model.prompts.single, contains('Request: What does this do?'));
  });

  test('a review without a project asks to open one', () async {
    await container
        .read(aiChatProvider.notifier)
        .send('', action: AiAction.dryReview);

    expect(
      container.read(aiChatProvider).messages.last.content,
      'Open a project to review it.',
    );
    expect(model.prompts, isEmpty);
  });

  test('the AI panel is busy during a task or an Ollama setup step', () {
    bool busy() => container.read(aiPanelBusyProvider);
    final chat = container.read(aiChatProvider.notifier);
    final setup = container.read(ollamaSetupRunningProvider.notifier);
    expect(busy(), isFalse);

    chat.beginTask('Translate with AI');
    expect(busy(), isTrue);
    chat.endTask('Translated');
    expect(busy(), isFalse);

    setup.state = true;
    expect(busy(), isTrue);
    setup.state = false;
    expect(busy(), isFalse);
  });

  test('shows a task with its progress until it ends', () {
    final chat = container.read(aiChatProvider.notifier);

    chat.beginTask('Translate with AI');
    chat.addReply('Translating 1–20 of 22 keys into French…', isProgress: true);
    expect(chat.isBusy, isTrue);
    chat.endTask('Translated 22 strings in 1 files');

    final state = container.read(aiChatProvider);
    expect(state.isBusy, isFalse);
    expect(state.messages.first.isUser, isTrue);
    expect(state.messages.last.content, 'Translated 22 strings in 1 files');
  });

  test('stops a pending task and its model requests', () {
    final task = AiCancelToken();
    final chat = container.read(aiChatProvider.notifier)
      ..beginTask('Translate with AI', cancel: task);

    chat.cancel();

    final state = container.read(aiChatProvider);
    expect(state.isBusy, isFalse);
    expect(state.messages.last.content, '⏹ Stopped.');
    expect(task.isCancelled, isTrue);
  });

  test('shows the reply as it streams in, until it lands', () async {
    final release = Completer<void>();
    final streaming = StreamingChatModel(
      start: 'It prints',
      answer: 'It prints a greeting.',
      release: release.future,
    );
    final streamed = ProviderContainer(
      overrides: [chatModelProvider.overrideWithValue(streaming)],
    );
    addTearDown(streamed.dispose);

    final reply = streamed
        .read(aiChatProvider.notifier)
        .send('Explain', action: AiAction.ask);
    await Future<void>.delayed(AppDuration.outputLogPublish * 2);
    expect(streamed.read(aiChatProvider).draft, 'It prints');

    release.complete();
    await reply;
    final chat = streamed.read(aiChatProvider);
    expect(chat.draft, isEmpty);
    expect(chat.messages.last.content, 'It prints a greeting.');
  });

  test('Ask AI answers a question without editing the project', () async {
    final project = Directory.systemTemp.createTempSync('fide_ask_');
    addTearDown(() => project.deleteSync(recursive: true));
    final agentModel = FakeChatModel(chatReplies: [answer('4')]);
    final asked = ProviderContainer(
      overrides: [chatModelProvider.overrideWithValue(agentModel)],
    );
    addTearDown(asked.dispose);
    asked.read(currentProjectPathProvider.notifier).state = project.path;

    await asked
        .read(aiChatProvider.notifier)
        .send('2+2=', action: AiAction.ask);

    expect(asked.read(aiChatProvider).messages.last.content, '4');
    expect(agentModel.toolNames.single, isNot(contains('write_file')));
    expect(agentModel.toolNames.single, isNot(contains('run_quick_fix')));
    // The open file isn't named to a question not about it
    expect(agentModel.chats.single.last['content'], '2+2=');
  });

  test('warms the model up', () async {
    await container.read(aiChatProvider.notifier).warmUp();

    expect(model.warmUps, 1);
  });
}
