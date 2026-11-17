import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the AI panel's work, which outlasts the panel, is running: a
/// chat reply or task, or an Ollama install, start or model download. The
/// AI tab rings its icon meanwhile, so it shows from the other tabs.
final aiPanelBusyProvider = Provider<bool>(
  (ref) =>
      ref.watch(aiChatProvider.select((chat) => chat.isBusy)) ||
      ref.watch(ollamaSetupRunningProvider),
);
