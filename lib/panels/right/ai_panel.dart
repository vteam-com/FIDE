// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/check_mark.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'ai_panel.chat_message.dart';

/// Represents `AIPanel`.
class AIPanel extends ConsumerStatefulWidget {
  const AIPanel({super.key, this.selectedFile});

  final FileSystemItem? selectedFile;

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
  bool _isLoading = false;
  bool _isOllamaRunning = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AiAction _selectedAction = AiAction.ask;
  @override
  void initState() {
    super.initState();

    /// Handles `_checkStatus`.
    _checkStatus();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Header with action selector

          // Setup instructions if no messages and not all ready
          if (_messages.isEmpty &&
              !(_hasOllamaInstalled && _isOllamaRunning && _hasModelInstalled))
            Container(
              padding: const EdgeInsets.all(AppSpacing.xLarge),
              margin: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: AppOpacity.divider),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Text(
                        'Setup',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  if (_isCheckingStatus)
                    const Center(child: CircularProgressIndicator())
                  else if (!_hasOllamaInstalled)
                    _buildSetupStep(
                      'Ollama is not installed.',
                      'Install Ollama',
                      _installOllama,
                    )
                  else if (!_isOllamaRunning)
                    _buildSetupStep(
                      'Ollama is installed but not running.',
                      'Run Ollama',
                      _runOllama,
                    )
                  else if (!_hasModelInstalled)
                    _buildSetupStep(
                      'Ollama is running but the ${OllamaInstaller.model} model is not downloaded.',
                      'Download Model',
                      _downloadModel,
                    )
                  else
                    const Text(
                      'Ollama is ready to use!',
                      style: TextStyle(fontSize: AppFontSize.caption),
                    ),
                ],
              ),
            ),

          // Chat area
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation with the AI assistant',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    itemCount: _messages.length,
                    itemBuilder: (_ /*context*/, index) {
                      final message = _messages[index];

                      /// Handles `_buildMessageBubble`.
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          Divider(),
          PopupMenuButton<AiAction>(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xLarge,
                vertical: AppSpacing.large,
              ),
              child: Row(
                children: [
                  Text(_selectedAction.label),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            itemBuilder: (_) => [
              for (final action in AiAction.values)
                PopupMenuItem(
                  value: action,
                  child: Row(
                    children: [
                      CheckMark(checked: action == _selectedAction),
                      const SizedBox(width: AppSpacing.medium),
                      Text(action.label),
                    ],
                  ),
                ),
            ],
            onSelected: (value) {
              setState(() => _selectedAction = value);
            },
          ),
          // Input area
          Row(
            spacing: AppSpacing.medium,
            children: [
              Expanded(
                // Enter sends; Shift+Enter, left unbound, starts a new line
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter):
                        _sendUnlessLoading,
                  },
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: _selectedAction.hint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large,
                        vertical: AppSpacing.medium,
                      ),
                    ),
                    maxLines: AppMetric.aiInputMaxLines,
                    minLines: 1,
                  ),
                ),
              ),

              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const InlineSpinner()
                    : const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ],
      ),
    );
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
        Text(message, style: const TextStyle(fontSize: AppFontSize.caption)),
        const SizedBox(height: AppSpacing.medium),
        if (_isInstalling)
          const CircularProgressIndicator()
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
            Text(
              message.content,
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (message.timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.tiny),
                child: Text(
                  /// Handles `_formatTimestamp`.
                  _formatTimestamp(message.timestamp!),
                  style: TextStyle(
                    fontSize: AppFontSize.badge,
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
          _hasModelInstalled = await _ollama.isModelInstalled();
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
      action: _ollama.downloadModel,
      onSuccess: () => _hasModelInstalled = true,
      successMessage: '${OllamaInstaller.model} model downloaded.',
      errorPrefix: 'Error downloading model',
    );
  }

  /// Handles `_formatTimestamp`.
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Installs Ollama, downloads the model and starts the service.
  Future<void> _installOllama() async {
    await _runInstallAction(
      action: _ollama.install,
      onSuccess: () {
        _hasOllamaInstalled = true;
        _isOllamaRunning = true;
        _hasModelInstalled = true;
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
    void Function()? onSuccess,
  }) async {
    setState(() => _isInstalling = true);
    try {
      await action();
      onSuccess?.call();
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

  /// Content of the selected file for the model, empty when none is
  /// selected.
  Future<String> _selectedFileContext() async {
    final file = widget.selectedFile;
    if (file == null) return '';
    try {
      return _truncateContext(await file.readAsString());
    } catch (_) {
      return 'Could not read file content';
    }
  }

  /// [text] cut to the context size sent to the model.
  String _truncateContext(String text) =>
      text.length > AppMetric.aiContextPreviewChars
      ? '${text.substring(0, AppMetric.aiContextPreviewChars)}...'
      : text;

  /// Sends the prompt from the keyboard, ignored while a reply is pending
  /// like the disabled Send button.
  void _sendUnlessLoading() {
    if (!_isLoading) _sendMessage();
  }

  /// Handles `_sendMessage`.
  Future<void> _sendMessage() async {
    final text = _promptController.text.trim();
    final action = _selectedAction;
    final buildErrors = ref.read(lastBuildErrorsProvider);
    // Fix Build needs no prompt when the last build left errors to send
    final canSendEmpty = action == AiAction.fixBuild && buildErrors.isNotEmpty;
    if (text.isEmpty && !canSendEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          content: text.isEmpty ? action.label : text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _promptController.clear();

    try {
      final context = action == AiAction.fixBuild
          ? _truncateContext(buildErrors)
          : await _selectedFileContext();

      final response = await _aiService.respond(action, text, context);

      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            content: response.trim().isEmpty
                ? 'No suggestion available'
                : response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            content: 'Error: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: AppDuration.messageAnimation,
            curve: Curves.easeOut,
          );
        });
      }
    }
  }
}
