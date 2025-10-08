// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import '../../models/file_system_item.dart';
import '../../utils/message_box.dart';

class AIPanel extends StatefulWidget {
  const AIPanel({super.key, this.selectedFile});

  final FileSystemItem? selectedFile;

  @override
  State<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends State<AIPanel> {
  final AIService _aiService = AIService();

  bool _isLoading = false;

  bool _isInstalling = false;

  bool _isCheckingStatus = true;

  bool _hasOllamaInstalled = false;

  bool _isOllamaRunning = false;

  bool _hasModelInstalled = false;

  final List<ChatMessage> _messages = [];

  final TextEditingController _promptController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  String _selectedAction = 'ask';

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkStatus();
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
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
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
                      const SizedBox(width: 8),
                      Text(
                        'Setup',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isCheckingStatus)
                    const Center(child: CircularProgressIndicator())
                  else if (!_hasOllamaInstalled)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ollama is not installed.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
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
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
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
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
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
                      style: TextStyle(fontSize: 12),
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
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          Divider(),
          PopupMenuButton<String>(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(_getActionText()),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'ask',
                child: Row(
                  children: [
                    if ('ask' == _selectedAction)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    const Text('Ask AI'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'explain',
                child: Row(
                  children: [
                    if ('explain' == _selectedAction)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    const Text('Explain Code'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'generate',
                child: Row(
                  children: [
                    if ('generate' == _selectedAction)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    const Text('Generate Code'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'refactor',
                child: Row(
                  children: [
                    if ('refactor' == _selectedAction)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
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
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    hintText: _getHintText(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTimestamp(message.timestamp!),
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser
                        ? Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.7)
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  String _getHintText() {
    switch (_selectedAction) {
      case 'ask':
        return 'Ask me anything about your code...';
      case 'explain':
        return 'Paste code here to get explanation...';
      case 'generate':
        return 'Describe what code you want to generate...';
      case 'refactor':
        return 'Paste code and describe how to refactor it...';
      default:
        return 'Type your message...';
    }
  }

  String _getActionText() {
    switch (_selectedAction) {
      case 'ask':
        return 'Ask AI';
      case 'explain':
        return 'Explain Code';
      case 'generate':
        return 'Generate Code';
      case 'refactor':
        return 'Refactor Code';
      default:
        return 'Select Action';
    }
  }

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
    } catch (e) {
      // Ollama not available
      _hasOllamaInstalled = false;
      _isOllamaRunning = false;
      _hasModelInstalled = false;
    }
    setState(() => _isCheckingStatus = false);
  }

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

  Future<void> _runOllama() async {
    setState(() => _isInstalling = true);
    try {
      await _aiService.startOllama();
      await _checkStatus();
      if (!mounted) return;
      MessageBox.showInfo(context, 'Ollama started.');
    } catch (e) {
      if (!mounted) return;
      MessageBox.showError(context, 'Error starting Ollama: $e');
    } finally {
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
  }

  Future<void> _downloadModel() async {
    setState(() => _isInstalling = true);
    try {
      await _aiService.downloadModel();
      _hasModelInstalled = true;
      if (!mounted) return;
      MessageBox.showInfo(context, 'codellama model downloaded.');
    } catch (e) {
      if (!mounted) return;
      MessageBox.showError(context, 'Error downloading model: $e');
    } finally {
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
  }

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
          if (context.length > 2000) {
            context = '${context.substring(0, 2000)}...';
          }
        } catch (e) {
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime? timestamp;

  ChatMessage({required this.content, required this.isUser, this.timestamp});
}
