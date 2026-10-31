import 'package:fide/models/ai_action.dart';
import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the AI panel and has it send [request] as an Ask AI prompt, so
/// the agent edits the project files to do it.
void askAi(WidgetRef ref, String request) {
  showAiPanel(ref);
  ref.read(aiChatProvider.notifier).send(request, action: AiAction.ask);
}

/// Shows the right panel on its AI tab, where the chat and its tasks are.
void showAiPanel(WidgetRef ref) {
  ref.read(rightPanelVisibleProvider.notifier).state = true;
  ref.read(activeRightPanelTabProvider.notifier).state = RightPanelTab.ai;
}
