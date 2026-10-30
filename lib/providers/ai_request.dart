import 'package:fide/models/right_panel_tab.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the AI panel and has it send [request] as an Ask AI prompt, so
/// the agent edits the project files to do it.
void askAi(WidgetRef ref, String request) {
  ref.read(aiRequestProvider.notifier).state = request;
  ref.read(rightPanelVisibleProvider.notifier).state = true;
  ref.read(activeRightPanelTabProvider.notifier).state = RightPanelTab.ai;
}
