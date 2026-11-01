// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/panels/right/ai_panel.ai_transcript_entry.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
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
  late final AIService _aiService = ref.read(aiServiceProvider);
  late final OllamaInstaller _ollama = ref.read(ollamaInstallerProvider);
  bool _hasModelInstalled = false;
  bool _hasOllamaInstalled = false;
  bool _isCheckingStatus = true;
  bool _isInstalling = false;
  bool _isOllamaRunning = false;
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    /// Handles `_checkStatus`.
    _checkStatus();

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
    ref.listen(
      aiChatProvider.select((chat) => chat.messages.length),
      (_, _) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd()),
    );
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Setup instructions if no messages and not all ready
          if (messages.isEmpty &&
              !(_hasOllamaInstalled && _isOllamaRunning && _hasModelInstalled))
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: ActionCard(
                title: 'Setup',
                icon: Icons.info_outline,
                child: _buildSetupState(),
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
          const Divider(height: AppSize.borderThin),
          _buildPrompt(chat.action.hint, chat.isBusy),
          _buildFooter(chat.action),
        ],
      ),
    );
  }

  /// The action new prompts use, as a menu, and the model answering them.
  Widget _buildFooter(AiAction selected) {
    final notifier = ref.read(aiChatProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        0,
        AppSpacing.large,
        AppSpacing.medium,
      ),
      child: Row(
        spacing: AppSpacing.medium,
        children: [
          PopupMenuButton<AiAction>(
            tooltip: 'Action',
            itemBuilder: (_) => [
              for (final action in AiAction.values)
                PopupMenuItem(
                  value: action,
                  child: IconMenuRow(
                    icon: action == selected ? Icons.check : null,
                    label: action.label,
                  ),
                ),
            ],
            onSelected: notifier.selectAction,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.tiny),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selected.label, style: AppTextStyle.caption),
                  const Icon(Icons.arrow_drop_down, size: AppIconSize.medium),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_hasModelInstalled)
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
      ),
    );
  }

  /// The prompt box with its Send button, or Stop while a reply is
  /// pending.
  Widget _buildPrompt(String hint, bool isBusy) {
    final notifier = ref.read(aiChatProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.tiny,
      ),
      // Enter sends; Shift+Enter, left unbound, starts a new line; Escape
      // stops the pending reply
      child: CallbackShortcuts(
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

  /// The first missing piece of the Ollama setup, or that it is ready.
  Widget _buildSetupState() {
    if (_isCheckingStatus) return const LoadingIndicator();
    if (!_hasOllamaInstalled) {
      return _buildSetupStep(
        'Ollama is not installed.',
        'Install Ollama',
        _installOllama,
      );
    }
    if (!_isOllamaRunning) {
      return _buildSetupStep(
        'Ollama is installed but not running.',
        'Run Ollama',
        _runOllama,
      );
    }
    if (!_hasModelInstalled) {
      return _buildSetupStep(
        'Ollama is running but no model is downloaded.',
        'Download Model',
        _downloadModel,
      );
    }
    return const Text('Ollama is ready to use!', style: AppTextStyle.caption);
  }

  /// One setup stage: what's missing and the button that fixes it, or a
  /// spinner while an install action runs.
  Widget _buildSetupStep(
    String message,
    String buttonLabel,
    VoidCallback onPressed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: AppTextStyle.caption),
        const SizedBox(height: AppSpacing.medium),
        if (_isInstalling)
          const InlineSpinner()
        else
          ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
      ],
    );
  }

  /// Handles `_checkStatus`.
  Future<void> _checkStatus() async {
    if (!mounted) return;
    setState(() => _isCheckingStatus = true);
    try {
      _hasOllamaInstalled = await _ollama.isInstalled();

      if (_hasOllamaInstalled) {
        _isOllamaRunning = await _ollama.isRunning();

        if (_isOllamaRunning) {
          _hasModelInstalled = await _aiService.resolveModel() != null;
        }
      } else {
        _isOllamaRunning = false;
        _hasModelInstalled = false;
      }
    } catch (_) {
      // Ollama not available
      _hasOllamaInstalled = false;
      _isOllamaRunning = false;
      _hasModelInstalled = false;
    }
    if (!mounted) return;
    setState(() => _isCheckingStatus = false);
  }

  /// Handles `_downloadModel`.
  Future<void> _downloadModel() async {
    await _runInstallAction(
      action: () async {
        await _ollama.downloadModel();
        await _checkStatus();
      },
      successMessage: '${OllamaInstaller.model} model downloaded.',
      errorPrefix: 'Error downloading model',
    );
  }

  /// Installs Ollama, downloads the model and starts the service.
  Future<void> _installOllama() async {
    await _runInstallAction(
      action: () async {
        await _ollama.install();
        await _checkStatus();
      },
      successMessage:
          'Ollama installed, ${OllamaInstaller.model} model downloaded, and service started.',
      errorPrefix: 'Error installing Ollama',
    );
  }

  /// Runs an install-related action with shared loading state and messages.
  Future<void> _runInstallAction({
    required Future<void> Function() action,
    String? successMessage,
    required String errorPrefix,
  }) async {
    setState(() => _isInstalling = true);
    try {
      await action();
      if (mounted && successMessage != null) {
        MessageBox.showInfo(context, successMessage);
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, '$errorPrefix: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
  }

  /// Handles `_runOllama`.
  Future<void> _runOllama() async {
    await _runInstallAction(
      action: () async {
        await _ollama.start();
        await _checkStatus();
      },
      successMessage: 'Ollama started.',
      errorPrefix: 'Error starting Ollama',
    );
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
