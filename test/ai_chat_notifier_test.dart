import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
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
        .send('What does this do?', action: AiAction.explain);

    final chat = container.read(aiChatProvider);
    expect(
      [for (final message in chat.messages) message.content],
      ['What does this do?', 'It prints a greeting.'],
    );
    expect(chat.isBusy, isFalse);
    expect(chat.action, AiAction.explain);
    expect(model.prompts.single, contains('Context: What does this do?'));
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
}
