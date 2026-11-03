import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [AiRequests] that hand work to the AI panel.
final aiRequestsProvider = Provider<AiRequests>(
  (ref) => AiRequests(
    chat: ref.watch(aiChatProvider.notifier),
    showPanel: () => showRightPanelTab(ref.read, RightPanelTab.ai),
  ),
);

/// Hands work to the AI panel from anywhere, including code that outlives
/// the widget that started it.
class AiRequests {
  /// Creates the requests sending prompts to [chat] after [showPanel]
  /// shows the AI panel.
  const AiRequests({required this.chat, required this.showPanel});

  /// The AI panel's conversation.
  final AiChatNotifier chat;

  /// Shows the right panel on its AI tab, where the chat and its tasks are.
  final VoidCallback showPanel;

  /// Shows the AI panel and has it send [request] as an Ask AI prompt, so
  /// the agent edits the project files to do it.
  void ask(String request) {
    showPanel();
    chat.send(request, action: AiAction.ask);
  }
}
