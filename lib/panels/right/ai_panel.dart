// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/panels/right/ai_panel.ai_transcript_entry.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:fide/services/ollama_installer.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/dropdown_label.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The AI assistant: the Ollama setup, the chat of [aiChatProvider],
/// which outlives this panel, and the prompt input.
class AIPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const AIPanel({super.key});

  @override
  ConsumerState<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends ConsumerState<AIPanel> {
  late final OllamaClient _aiService = ref.read(ollamaClientProvider);
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
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: ActionCard(
              title: 'Setup',
              icon: Icons.info_outline,
              child: _buildSetupState(setup.value),
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
        PopupMenuButton<AiAction>(
          tooltip: 'Action',
          itemBuilder: (_) => [
            for (final action in AiAction.values)
              IconMenuItem(
                value: action,
                icon: action == selected ? Icons.check : null,
                label: action.label,
              ),
          ],
          onSelected: notifier.selectAction,
          child: DropdownLabel(
            child: Text(selected.label, style: AppTextStyle.caption),
          ),
        ),
        const Spacer(),
        if (isReady)
          Flexible(
            child: Tooltip(
              message: _modelLabel,
              child: Text(
                _modelLabel,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.secondary(context),
              ),
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
        trailing: isBusy
            ? CompactIconButton(
                onPressed: notifier.cancel,
                icon: Icons.stop_circle_outlined,
                tooltip: 'Stop (Esc)',
              )
            : CompactIconButton(
                onPressed: _send,
                icon: Icons.arrow_upward,
                tooltip: 'Send (Enter)',
              ),
      ),
    );
  }

  /// The last transcript line while a reply or task is pending.
  Widget _buildWorking() {
    return SelectionContainer.disabled(
      child: Row(
        spacing: AppSpacing.medium,
        children: [
          const InlineSpinner(size: AppIconSize.tiny),
          Text('Working… Esc to stop', style: AppTextStyle.secondary(context)),
        ],
      ),
    );
  }

  /// The first missing piece of the Ollama setup, with the button that
  /// fixes it, a spinner while a fix runs, or that it is ready; [step] is
  /// null while it is being checked.
  Widget _buildSetupState(OllamaStep? step) {
    if (step == null) return const LoadingIndicator();
    final actionLabel = step.actionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        Text(step.message, style: AppTextStyle.caption),
        if (step == OllamaStep.installing)
          const InlineSpinner()
        else if (actionLabel != null)
          PrimaryButton(onPressed: () => _fixSetup(step), label: actionLabel),
      ],
    );
  }

  /// Runs the fix of setup [step] and reports how it went.
  Future<void> _fixSetup(OllamaStep step) async {
    try {
      final done = await ref.read(ollamaStatusProvider.notifier).fix();
      if (mounted && done != null) MessageBox.showInfo(context, done);
    } catch (e) {
      if (mounted) MessageBox.showError(context, '${step.errorPrefix}: $e');
    }
  }

  /// The model in use, noting when it stands in for the preferred one.
  String get _modelLabel => _aiService.isFallbackModel
      ? '${_aiService.model} (${OllamaInstaller.model} not available)'
      : _aiService.model;

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
