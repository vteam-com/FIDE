import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [AiRequests] that hand work to the AI panel.
final aiRequestsProvider = Provider<AiRequests>((ref) => AiRequests(ref));

/// Hands work to the AI panel from anywhere, including code that outlives
/// the widget that started it.
class AiRequests {
  /// Creates the requests, reaching the panel through [_ref].
  const AiRequests(this._ref);

  final Ref _ref;

  /// Shows the AI panel and has it send [request] as an Ask AI prompt, so
  /// the agent edits the project files to do it.
  void ask(String request) {
    showPanel();
    _ref.read(aiChatProvider.notifier).send(request, action: AiAction.ask);
  }

  /// Shows the right panel on its AI tab, where the chat and its tasks are.
  void showPanel() => showRightPanelTab(_ref.read, RightPanelTab.ai);
}
