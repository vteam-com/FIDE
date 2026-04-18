// ignore_for_file: deprecated_member_use

import 'package:fide/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/ai_service.dart';
import 'package:fide/utils/message_box.dart';
import 'package:flutter/material.dart';

/// Represents `AIPanel`.
class AIPanel extends StatefulWidget {
  const AIPanel({super.key, this.selectedFile});

  final FileSystemItem? selectedFile;

  @override
  State<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends State<AIPanel> {
  static const Map<String, String> _actionHints = {
    'ask': 'Ask me anything about your code...',
    'explain': 'Paste code here to get explanation...',
    'generate': 'Describe what code you want to generate...',
    'refactor': 'Paste code and describe how to refactor it...',
  };
  static const Map<String, String> _actionLabels = {
    'ask': 'Ask AI',
    'explain': 'Explain Code',
    'generate': 'Generate Code',
    'refactor': 'Refactor Code',
  };
  final AIService _aiService = AIService();
  bool _hasModelInstalled = false;
  bool _hasOllamaInstalled = false;
  bool _isCheckingStatus = true;
  bool _isInstalling = false;
  bool _isLoading = false;
  bool _isOllamaRunning = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedAction = 'ask';
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
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: AppOpacity.divider),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ollama is not installed.',
                          style: TextStyle(fontSize: AppFontSize.caption),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (_isInstalling)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _installOllama,
                            child: const Text('Install Ollama'),
                          ),
                      ],
                    )
                  else if (!_isOllamaRunning)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ollama is installed but not running.',
                          style: TextStyle(fontSize: AppFontSize.caption),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (_isInstalling)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _runOllama,
                            child: const Text('Run Ollama'),
                          ),
                      ],
                    )
                  else if (!_hasModelInstalled)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ollama is running but the codellama model is not downloaded.',
                          style: TextStyle(fontSize: AppFontSize.caption),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (_isInstalling)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _downloadModel,
                            child: const Text('Download Model'),
                          ),
                      ],
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
          PopupMenuButton<String>(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xLarge,
                vertical: AppSpacing.large,
              ),
              child: Row(
                children: [
                  /// Handles `_getActionText`.
                  Text(_getActionText()),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'ask',
                child: Row(
                  children: [
                    if ('ask' == _selectedAction)
                      const Icon(Icons.check, size: AppIconSize.mediumLarge)
                    else
                      const SizedBox(width: AppIconSize.mediumLarge),
                    const SizedBox(width: AppSpacing.medium),
                    const Text('Ask AI'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'explain',
                child: Row(
                  children: [
                    if ('explain' == _selectedAction)
                      const Icon(Icons.check, size: AppIconSize.mediumLarge)
                    else
                      const SizedBox(width: AppIconSize.mediumLarge),
                    const SizedBox(width: AppSpacing.medium),
                    const Text('Explain Code'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'generate',
                child: Row(
                  children: [
                    if ('generate' == _selectedAction)
                      const Icon(Icons.check, size: AppIconSize.mediumLarge)
                    else
                      const SizedBox(width: AppIconSize.mediumLarge),
                    const SizedBox(width: AppSpacing.medium),
                    const Text('Generate Code'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'refactor',
                child: Row(
                  children: [
                    if ('refactor' == _selectedAction)
                      const Icon(Icons.check, size: AppIconSize.mediumLarge)
                    else
                      const SizedBox(width: AppIconSize.mediumLarge),
                    const SizedBox(width: AppSpacing.medium),
                    const Text('Refactor Code'),
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
                child: TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    /// Handles `_getHintText`.
                    hintText: _getHintText(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                      vertical: AppSpacing.medium,
                    ),
                  ),
                  maxLines: AppMetric.aiInputMaxLines,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: AppIconSize.large,
                        height: AppIconSize.large,
                        child: CircularProgressIndicator(
                          strokeWidth: AppBorderWidth.medium,
                        ),
                      )
                    : const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ],
      ),
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
                        ? Theme.of(context).colorScheme.onPrimary.withValues(
                            alpha: AppOpacity.secondaryText,
                          )
                        : Theme.of(context).colorScheme.onSurface.withValues(
                            alpha: AppOpacity.disabled,
                          ),
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
    setState(() => _isCheckingStatus = true);
    try {
      _hasOllamaInstalled = await _aiService.isOllamaInstalled();

      if (_hasOllamaInstalled) {
        _isOllamaRunning = await _aiService.isOllamaRunning();

        if (_isOllamaRunning) {
          _hasModelInstalled = await _aiService.isModelInstalled();
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
    setState(() => _isCheckingStatus = false);
  }

  /// Handles `_downloadModel`.
  Future<void> _downloadModel() async {
    await _runInstallAction(
      action: _aiService.downloadModel,
      onSuccess: () => _hasModelInstalled = true,
      successMessage: 'codellama model downloaded.',
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

  /// Handles `_getActionText`.
  String _getActionText() {
    return _actionLabels[_selectedAction] ?? 'Select Action';
  }

  /// Handles `_getHintText`.
  String _getHintText() {
    return _actionHints[_selectedAction] ?? 'Type your message...';
  }

  /// Handles `_installOllama`.
  Future<void> _installOllama() async {
    setState(() => _isInstalling = true);
    try {
      await _aiService.installOllama();

      _hasOllamaInstalled = true;
      _isOllamaRunning = true;
      _hasModelInstalled = true;

      if (mounted) {
        MessageBox.showInfo(
          context,
          'Ollama installed, codellama model downloaded, and service started.',
        );
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error installing Ollama: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
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
        await _aiService.startOllama();
        await _checkStatus();
      },
      successMessage: 'Ollama started.',
      errorPrefix: 'Error starting Ollama',
    );
  }

  /// Handles `_sendMessage`.
  Future<void> _sendMessage() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(content: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    _promptController.clear();

    try {
      String response;
      String context = '';

      // Get context from selected file if available
      if (widget.selectedFile != null) {
        try {
          context = await widget.selectedFile!.readAsString();
          if (context.length > AppMetric.aiContextPreviewChars) {
            context =
                '${context.substring(0, AppMetric.aiContextPreviewChars)}...';
          }
        } catch (_) {
          context = 'Could not read file content';
        }
      }

      switch (_selectedAction) {
        case 'explain':
          response = await _aiService.explainCode(text);
          break;
        case 'generate':
          response = await _aiService.generateCode(text);
          break;
        case 'refactor':
          response = await _aiService.refactorCode(
            text,
            'Please refactor this code',
          );
          break;
        default:
          response = await _aiService.getCodeSuggestion(text, context);
      }

      setState(() {
        _messages.add(
          ChatMessage(
            content: response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
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
      setState(() => _isLoading = false);
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDuration.messageAnimation,
          curve: Curves.easeOut,
        );
      });
    }
  }
}

/// Represents `ChatMessage`.
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime? timestamp;

  ChatMessage({required this.content, required this.isUser, this.timestamp});
}
