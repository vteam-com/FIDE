// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import '../../models/file_system_item.dart';

class AIPanel extends StatefulWidget {
  const AIPanel({super.key, this.selectedFile});

  final FileSystemItem? selectedFile;

  @override
  State<AIPanel> createState() => _AIPanelState();
}

class _AIPanelState extends State<AIPanel> {
  final AIService _aiService = AIService();

  bool _isLoading = false;

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
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Header with action selector
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedAction,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'ask', child: Text('Ask AI')),
                      DropdownMenuItem(
                        value: 'explain',
                        child: Text('Explain Code'),
                      ),
                      DropdownMenuItem(
                        value: 'generate',
                        child: Text('Generate Code'),
                      ),
                      DropdownMenuItem(
                        value: 'refactor',
                        child: Text('Refactor Code'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedAction = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Setup instructions if no messages
          if (_messages.isEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
                        'Setup Required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To use AI features, you need to install and run Ollama locally:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Install Ollama: https://ollama.ai/download',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '2. Pull a coding model: ollama pull codellama',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '3. Start Ollama (it runs automatically)',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alternative models: llama2, mistral, deepseek-coder',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

          // Input area
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
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
                const SizedBox(width: 8),
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
                          ).colorScheme.onPrimary.withOpacity(0.7)
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
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
