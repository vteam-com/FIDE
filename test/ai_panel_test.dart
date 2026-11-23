import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/chat_message.dart';
import 'package:fide/models/local_model.dart';
import 'package:fide/panels/right/ai_panel.ai_transcript_entry.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/gestures.dart';
import 'package:fide/models/ollama_model.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/panels/right/ai_panel.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ollama_model_provider.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_chat_model.dart';

/// An Ollama setup found ready, without checking the machine, recording
/// the models picked instead of downloading them.
class _Ready extends OllamaStatusNotifier {
  /// The models picked, in order.
  static final List<LocalModel> picked = [];

  @override
  Future<OllamaStep> build() async => OllamaStep.ready;

  @override
  Future<String?> use(LocalModel model) async {
    picked.add(model);
    return null;
  }
}

/// Tag of the model the panel answers with.
final String _mimo = LocalModel.defaultModel.tag;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Pumps the AI panel asking [model], with the local model ready.
  Future<ProviderContainer> pump(WidgetTester tester, ChatModel model) async {
    final container = ProviderContainer(
      overrides: [
        chatModelProvider.overrideWithValue(model),
        ollamaStatusProvider.overrideWith(_Ready.new),
        ollamaModelProvider.overrideWithValue(
          OllamaModel(
            name: _mimo,
            isFallback: false,
            preferred: _mimo,
            downloaded: {_mimo},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AIPanel())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('names the local model once it is ready', (tester) async {
    await pump(tester, FakeChatModel());

    expect(find.text(LocalModel.mimo.label), findsOneWidget);
    expect(find.text('Setup'), findsNothing);
  });

  testWidgets('picks the local model from a menu of those offered', (
    tester,
  ) async {
    _Ready.picked.clear();
    await pump(tester, FakeChatModel());

    await tester.tap(find.text(LocalModel.mimo.label));
    await tester.pumpAndSettle();

    // Each with the memory it needs; the one in use checked, those not
    // downloaded marked
    for (final model in LocalModel.values) {
      expect(find.text('${model.minMemoryGb} GB+ RAM'), findsWidgets);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.download), findsNWidgets(2));

    await tester.tap(find.text(LocalModel.qwen38.label));
    await tester.pumpAndSettle();
    expect(_Ready.picked, [LocalModel.qwen38]);
  });

  testWidgets('shows the reply as it streams in', (tester) async {
    final release = Completer<void>();
    final container = await pump(
      tester,
      StreamingChatModel(
        start: 'A widget',
        answer: 'A widget that never changes.',
        release: release.future,
      ),
    );

    unawaited(
      container
          .read(aiChatProvider.notifier)
          .send('What is it?', action: AiAction.ask),
    );
    await tester.pump(AppDuration.outputLogPublish);
    await tester.pump();
    expect(find.text('A widget'), findsOneWidget);

    release.complete();
    await tester.pumpAndSettle();
    expect(find.text('A widget that never changes.'), findsOneWidget);
    expect(find.text('Working… Esc to stop'), findsNothing);
  });

  testWidgets('focusing the prompt gets the model ready', (tester) async {
    final model = FakeChatModel();
    await pump(tester, model);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(model.warmUps, 1);
  });

  testWidgets('a one-line step is as tall as its hover toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTranscriptEntry(
            message: ChatMessage(
              content: '🔧 check_build',
              isUser: false,
              isProgress: true,
              timestamp: DateTime.now(),
            ),
          ),
        ),
      ),
    );
    final entry = find.byType(AiTranscriptEntry);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(entry));
    await tester.pump();

    final toolbar = find.byType(CopyButton);
    expect(toolbar, findsOneWidget);
    // The toolbar lies within the entry, so nothing clips it
    expect(
      tester
          .getRect(entry)
          .contains(tester.getBottomRight(toolbar) - const Offset(1, 1)),
      isTrue,
    );
  });
}
