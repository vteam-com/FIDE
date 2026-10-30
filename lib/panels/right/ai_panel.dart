// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/code_edit_agent.dart';
import 'package:fide/providers/flutter_build_service.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/check_mark.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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
                      'Ollama is running but no model is downloaded.',
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
                  if (_hasModelInstalled)
                    Flexible(
                      child: Tooltip(
                        message: _modelLabel,
                        child: Text(
                          _modelLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: AppOpacity.disabled),
                          ),
                        ),
                      ),
                    ),
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Row(
              spacing: AppSpacing.medium,
              children: [
                Expanded(
                  // Enter sends; Shift+Enter, left unbound, starts a new line
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter):
                          _sendUnlessLoading,
                    },
                    child: AppTextField(
                      controller: _promptController,
                      hintText: _selectedAction.hint,
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
            if (isUser)
              Text(
                message.content,
                style: TextStyle(
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

  /// Content of the selected file for the model, empty when none is
  /// selected.
  Future<String> _selectedFileContext() async {
    final file = widget.selectedFile;
    if (file == null) return '';
    try {
      return (await file.readAsString()).truncated(
        AppMetric.aiContextPreviewChars,
      );
    } catch (_) {
      return 'Could not read file content';
    }
  }

  /// fcheck's findings for the project at [projectPath] that the review
  /// [action] needs, with the code they point to.
  Future<String> _reviewFindings(AiAction action, String projectPath) async {
    final review = ref.read(codeReviewProvider);
    _addReply('🔍 Analyzing the project with fcheck...', isProgress: true);
    final isDry = action == AiAction.dryReview;
    final metrics = await review.analyze(projectPath, nearDuplicates: isDry);
    return isDry ? review.duplicates(metrics) : review.design(metrics);
  }

  /// Sends the prompt from the keyboard, ignored while a reply is pending
  /// like the disabled Send button.
  void _sendUnlessLoading() {
    if (!_isLoading) _sendMessage();
  }

  /// Adds a model message showing [content] and scrolls to it;
  /// [isProgress] keeps it out of the history sent to the model.
  void _addReply(String content, {bool isProgress = false}) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          content: content,
          isUser: false,
          isProgress: isProgress,
          timestamp: DateTime.now(),
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDuration.messageAnimation,
        curve: Curves.easeOut,
      );
    });
  }

  /// The chat before the latest user message, without progress lines, as
  /// Ollama messages: the last [AppMetric.aiChatHistoryMessages], each cut
  /// to [AppMetric.aiMaxReadChars].
  List<Map<String, String>> _chatHistory() {
    final earlier = _messages
        .take(_messages.length - 1)
        .where((message) => !message.isProgress)
        .toList();
    return [
      for (final message in earlier.skip(
        (earlier.length - AppMetric.aiChatHistoryMessages).clamp(
          0,
          earlier.length,
        ),
      ))
        {
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.content.truncated(AppMetric.aiMaxReadChars),
        },
    ];
  }

  /// [text] with the path of the file open in the editor, relative to
  /// [projectPath], so "this file" in the request can be resolved.
  String _withSelectedFile(String text, String projectPath) {
    final file = widget.selectedFile;
    if (file == null) return text;
    return '$text\n\n(The file open in the editor is '
        '${p.relative(file.path, from: projectPath)}.)';
  }

  /// An agent that edits the project at [projectPath], reporting its steps
  /// in the chat and rebuilding for the platform selected in the Execute
  /// panel.
  ///
  /// Providers are read up front because the edit can outlive this panel.
  CodeEditAgent _editAgent(String projectPath) {
    final buildService = ref.read(flutterBuildServiceProvider);
    final target = ref.read(selectedPlatformProvider).name;
    final lastBuildErrors = ref.read(lastBuildErrorsProvider.notifier);
    final openDocuments = ref.read(openDocumentsProvider.notifier);
    return CodeEditAgent(
      _aiService,
      projectPath: projectPath,
      hooks: CodeEditHooks(
        onStep: (step) => _addReply('🔧 $step', isProgress: true),
        onFileWritten: (path) => openDocuments.reloadWritten([path]),
        checkBuild: () async {
          final log = OutputLog();
          final exitCode = await buildService.build(
            projectPath,
            target,
            BuildOutput(
              onOutput: log.addOutput,
              onError: log.addError,
              onResetErrors: log.clearErrors,
            ),
          );
          final buildErrors = exitCode == 0
              ? ''
              : (log.hasErrors ? log.errors : log.output);
          lastBuildErrors.state = buildErrors;
          return buildErrors;
        },
      ),
    );
  }

  /// Sends the prompt for the selected action and shows the reply.
  ///
  /// Actions that [AiAction.editsFiles] change the open project's files
  /// themselves, with the earlier chat as context; with no project open, or
  /// a model that can't call tools, they only suggest changes. After a
  /// review the panel switches to Ask AI, so the next message, like "fix
  /// 1", acts on the review.
  Future<void> _sendMessage() async {
    final text = _promptController.text.trim();
    final action = _selectedAction;
    final buildErrors = ref.read(lastBuildErrorsProvider);
    final projectPath = ref.read(currentProjectPathProvider);
    // Fix Build needs no prompt when the last build left errors to send;
    // reviews send fcheck's findings
    final canSendEmpty =
        (action == AiAction.fixBuild && buildErrors.isNotEmpty) ||
        action.isReview;
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

    // Models without tool calling can only suggest changes
    final canEditFiles = projectPath != null && _aiService.supportsTools;
    if (action.editsFiles && projectPath != null && !canEditFiles) {
      _addReply(
        "${_aiService.model} can't call tools, so it can only suggest "
        'changes. Download ${OllamaInstaller.model} to let it edit files.',
        isProgress: true,
      );
    }

    try {
      if (action.isReview && projectPath == null) {
        _addReply('Open a project to review it.');
        return;
      }
      final response = switch (action) {
        AiAction.fixBuild when canEditFiles => await _editAgent(
          projectPath,
        ).fixBuild(buildErrors, text),
        _ when action.editsFiles && canEditFiles => await _editAgent(
          projectPath,
        ).edit(_withSelectedFile(text, projectPath), _chatHistory()),
        _ => await _aiService.respond(action, text, switch (action) {
          AiAction.fixBuild => buildErrors.truncated(
            AppMetric.aiContextPreviewChars,
          ),
          _ when action.isReview => await _reviewFindings(action, projectPath!),
          _ => await _selectedFileContext(),
        }),
      };
      _addReply(response.trim().isEmpty ? 'No suggestion available' : response);
      if (action.isReview && mounted) {
        setState(() => _selectedAction = AiAction.ask);
        _addReply(
          'Switched to ${AiAction.ask.label}: say what to fix, e.g. '
          '"fix 1 and 3", and the changes are made in the files.',
          isProgress: true,
        );
      }
    } catch (e) {
      _addReply('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
