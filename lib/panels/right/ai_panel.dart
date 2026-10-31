// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/chat_message.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/markdown_text.dart';
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
    final notifier = ref.read(aiChatProvider.notifier);
    ref.listen(
      aiChatProvider.select((chat) => chat.messages.length),
      (_, _) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd()),
    );
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Header with action selector

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

          // Chat area
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    message: 'Start a conversation with the AI assistant',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    itemCount: messages.length,
                    itemBuilder: (_ /*context*/, index) {
                      final message = messages[index];

                      /// Handles `_buildMessageBubble`.
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          Divider(),
          PopupMenuButton<AiAction>(
            itemBuilder: (_) => [
              for (final action in AiAction.values)
                PopupMenuItem(
                  value: action,
                  child: IconMenuRow(
                    icon: action == chat.action ? Icons.check : null,
                    label: action.label,
                  ),
                ),
            ],
            onSelected: notifier.selectAction,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xLarge,
                vertical: AppSpacing.large,
              ),
              child: Row(
                children: [
                  Text(chat.action.label),
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
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          // Input area
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Row(
              spacing: AppSpacing.medium,
              children: [
                Expanded(
                  // Enter sends; Shift+Enter, left unbound, starts a new
                  // line; Escape stops the pending reply
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter): _send,
                      const SingleActivator(LogicalKeyboardKey.escape):
                          notifier.cancel,
                    },
                    child: AppTextField(
                      controller: _promptController,
                      hintText: chat.action.hint,
                      maxLines: AppMetric.aiInputMaxLines,
                      minLines: 1,
                    ),
                  ),
                ),

                if (chat.isBusy) const InlineSpinner(),
                chat.isBusy
                    ? IconButton(
                        onPressed: notifier.cancel,
                        icon: const Icon(Icons.stop_circle_outlined),
                        tooltip: 'Stop (Esc)',
                      )
                    : IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                        tooltip: 'Send',
                      ),
              ],
            ),
          ),
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

  /// Handles `_buildMessageBubble`.
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.tiny),
        padding: const EdgeInsets.all(AppSpacing.large),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * AppOpacity.emphasis,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.large),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                message.content,
                style: AppTextStyle.label.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            else
              MarkdownText(
                data: message.content,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            if (message.timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.tiny),
                child: Text(
                  message.timestamp!.timeAgo(),
                  style: AppTextStyle.badge.copyWith(
                    color: isUser
                        ? Theme.of(context).colorScheme.onPrimary
                              .withValues(alpha: AppOpacity.secondaryText)
                        : Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: AppOpacity.disabled),
                  ),
                ),
              ),
          ],
        ),
      ),
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
