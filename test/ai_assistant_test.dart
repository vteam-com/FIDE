import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/services/ai_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_model.dart';

void main() {
  late FakeChatModel model;
  late AiAssistant assistant;

  setUp(() {
    model = FakeChatModel(answer: (_) => 'fixed');
    assistant = AiAssistant(model);
  });

  test('fix build sends the build errors with the notes', () async {
    final response = await assistant.respond(
      AiAction.fixBuild,
      'Only main.dart changed',
      "lib/main.dart:3:1: Error: Expected ';'",
    );

    expect(response, 'fixed');
    expect(model.prompts.single, contains("Expected ';'"));
    expect(
      model.prompts.single,
      contains('${AiAction.fixBuild.instruction}\n\nOnly main.dart changed'),
    );
    expect(model.thinks, [true]);
  });

  test('actions without context work on the prompt itself', () async {
    await assistant.respond(AiAction.explain, 'void main() {}', 'ignored');

    expect(model.prompts.single, contains('Context: void main() {}'));
    expect(
      model.prompts.single,
      contains('Request: ${AiAction.explain.instruction}'),
    );
    expect(model.prompts.single, isNot(contains('ignored')));
    expect(model.thinks, [false]);
  });

  test('ask sends the question with the selected file', () async {
    await assistant.respond(AiAction.ask, 'What is this?', 'class A {}');

    expect(model.prompts.single, contains('Context: class A {}'));
    expect(model.prompts.single, contains('Request: What is this?'));
  });

  test('reviews send the action instructions and think', () async {
    await assistant.respond(AiAction.solidReview, 'focus', 'findings');

    expect(model.prompts.single, contains(AiAction.solidReview.instruction));
    expect(model.prompts.single, endsWith('focus\n\nfindings'));
    expect(model.thinks, [true]);
    expect(model.timeouts, [AppDuration.aiReviewTimeout]);
  });
}
