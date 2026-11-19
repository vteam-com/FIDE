// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/panels/right/ai_panel.ai_transcript_entry.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ollama_model_provider.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/widget_services/ollama_setup_action.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/dropdown_menu_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The AI assistant: the Ollama setup, the chat of [aiChatProvider],
/// which outlives this panel, and the prompt input.
class AIPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const AIPanel({super.key});

  @override
  ConsumerState<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends ConsumerState<AIPanel> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Back to the latest message of a chat kept while the panel was hidden
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiChatProvider);
    final messages = chat.messages;
    final setup = ref.watch(ollamaStatusProvider);
    final isReady = setup.value == OllamaStep.ready;
    ref.listen(
      aiChatProvider.select((chat) => chat.messages.length),
      (_, _) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd()),
    );
    return Column(
      children: [
        // Setup instructions if no messages and not all ready
        if (messages.isEmpty && !isReady)
          Padding(
            padding: AppPadding.panelContent,
            child: ActionCard(
              title: 'Setup',
              icon: Icons.info_outline,
              child: const OllamaSetupAction(),
            ),
          ),

        // Transcript: one selection spans every entry
        Expanded(
          child: messages.isEmpty && !chat.isBusy
              ? const EmptyState(
                  message: 'Start a conversation with the AI assistant',
                )
              : SelectionArea(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.large),
                    itemCount: messages.length + (chat.isBusy ? 1 : 0),
                    separatorBuilder: (_ /*context*/, _ /*index*/) =>
                        const SizedBox(height: AppSpacing.large),
                    itemBuilder: (_ /*context*/, index) =>
                        index < messages.length
                        ? AiTranscriptEntry(message: messages[index])
                        : _buildWorking(),
                  ),
                ),
        ),
        HeaderBar(
          isFooter: true,
          child: Column(
            spacing: AppSpacing.tiny,
            children: [
              _buildPrompt(chat.action.hint, chat.isBusy),
              _buildFooter(chat.action, isReady),
            ],
          ),
        ),
      ],
    );
  }

  /// The action new prompts use, as a menu, and the model answering them.
  Widget _buildFooter(AiAction selected, bool isReady) {
    final notifier = ref.read(aiChatProvider.notifier);
    return Row(
      spacing: AppSpacing.medium,
      children: [
        DropdownMenuButton<AiAction>(
          tooltip: 'Action',
          initialValue: selected,
          itemBuilder: (_) => [
            for (final action in AiAction.values)
              IconMenuItem(
                value: action,
                icon: action == selected ? Icons.check : null,
                label: action.label,
              ),
          ],
          onSelected: notifier.selectAction,
          label: Text(selected.label, style: AppTextStyle.caption),
        ),
        const Spacer(),
        if (isReady)
          Flexible(
            child: TruncatedText(
              ref.watch(ollamaModelProvider).label,
              style: AppTextStyle.secondary(context),
            ),
          ),
      ],
    );
  }

  /// The prompt box with its Send button, or Stop while a reply is
  /// pending.
  Widget _buildPrompt(String hint, bool isBusy) {
    final notifier = ref.read(aiChatProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _send,
        const SingleActivator(LogicalKeyboardKey.escape): notifier.cancel,
      },
      child: AppTextField(
        controller: _promptController,
        hintText: hint,
        maxLines: AppMetric.aiInputMaxLines,
        minLines: 1,
        trailing: TaskButton(
          icon: Icons.arrow_upward,
          tooltip: 'Send (Enter)',
          running: isBusy,
          onRun: _send,
          onStop: notifier.cancel,
        ),
      ),
    );
  }

  /// The last transcript line while a reply or task is pending; the ring
  /// around the prompt's Stop button shows the progress.
  Widget _buildWorking() {
    return SelectionContainer.disabled(
      child: Text(
        'Working… Esc to stop',
        style: AppTextStyle.secondary(context),
      ),
    );
  }

  /// Scrolls the chat to its latest message.
  void _scrollToEnd() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: AppDuration.messageAnimation,
      curve: Curves.easeOut,
    );
  }

  /// Sends the prompt, ignored while a reply is pending like the disabled
  /// Send button.
  void _send() {
    final chat = ref.read(aiChatProvider.notifier);
    if (ref.read(aiChatProvider).isBusy) return;
    final text = _promptController.text.trim();
    _promptController.clear();
    chat.send(text);
  }
}
