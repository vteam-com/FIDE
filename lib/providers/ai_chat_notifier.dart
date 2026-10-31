import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/ai_chat.dart';
import 'package:fide/models/chat_message.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/code_edit_agent.dart';
import 'package:fide/providers/flutter_build_service.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

/// The AI panel's conversation, which outlives the panel: hiding it or
/// switching tabs keeps the messages, and a pending reply or task still
/// lands in the chat.
final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChat>(
  (ref) => AiChatNotifier(ref),
);

/// Runs the AI panel's conversation: sends prompts for the selected
/// action, lets the agent edit files, shows tasks such as Translate with
/// AI, and stops whatever is pending.
class AiChatNotifier extends StateNotifier<AiChat> {
  /// Creates an empty conversation reading services through [_ref].
  AiChatNotifier(this._ref) : super(const AiChat());

  /// The agent editing files for the pending request, if any.
  CodeEditAgent? _agent;

  final Ref _ref;

  /// Bumped per request and by [cancel], so a stopped request's late
  /// reply is dropped.
  int _requestId = 0;

  /// The model service.
  AIService get _ai => _ref.read(aiServiceProvider);

  /// Adds a model message showing [content]; [isProgress] keeps it out of
  /// the history sent to the model.
  void addReply(String content, {bool isProgress = false}) => _add(
    ChatMessage(
      content: content,
      isUser: false,
      isProgress: isProgress,
      timestamp: DateTime.now(),
    ),
  );

  /// Shows a task named [label], such as a quick fix, as the user's
  /// request and marks the chat busy until [endTask].
  void beginTask(String label) {
    _requestId++;
    _add(ChatMessage(content: label, isUser: true, timestamp: DateTime.now()));
    state = state.copyWith(isBusy: true);
  }

  /// Stops the pending reply or task: aborts the model request and the
  /// agent's edits, and frees the input for the next prompt.
  void cancel() {
    if (!state.isBusy) return;
    (_agent?.cancel ?? _ai.cancel)();
    _agent = null;
    _requestId++;
    state = state.copyWith(isBusy: false);
    addReply('⏹ Stopped.', isProgress: true);
  }

  /// Ends the task [beginTask] started with its outcome, [reply].
  void endTask(String reply) {
    addReply(reply);
    state = state.copyWith(isBusy: false);
  }

  /// Makes [action] the one new prompts use.
  void selectAction(AiAction action) => state = state.copyWith(action: action);

  /// Sends [text] for the selected action, or [action] when given, and
  /// shows the reply; ignored while a reply is pending.
  ///
  /// Actions that [AiAction.editsFiles] change the open project's files
  /// themselves, with the earlier chat as context; with no project open, or
  /// a model that can't call tools, they only suggest changes. After a
  /// review the chat switches to Ask AI, so the next message, like "fix
  /// 1", acts on the review.
  Future<void> send(String text, {AiAction? action}) async {
    if (state.isBusy) return;
    final selected = action ?? state.action;
    final buildErrors = _ref.read(lastBuildErrorsProvider);
    final projectPath = _ref.read(currentProjectPathProvider);
    // Fix Build needs no prompt when the last build left errors to send;
    // reviews send fcheck's findings
    final canSendEmpty =
        (selected == AiAction.fixBuild && buildErrors.isNotEmpty) ||
        selected.isReview;
    if (text.isEmpty && !canSendEmpty) return;

    final requestId = ++_requestId;
    bool isStopped() => requestId != _requestId;
    _add(
      ChatMessage(
        content: text.isEmpty ? selected.label : text,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    state = state.copyWith(action: selected, isBusy: true);

    // Models without tool calling can only suggest changes
    final canEditFiles = projectPath != null && _ai.supportsTools;
    if (selected.editsFiles && projectPath != null && !canEditFiles) {
      addReply(
        "${_ai.model} can't call tools, so it can only suggest changes. "
        'Download ${OllamaInstaller.model} to let it edit files.',
        isProgress: true,
      );
    }

    try {
      if (selected.isReview && projectPath == null) {
        addReply('Open a project to review it.');
        return;
      }
      final response = switch (selected) {
        AiAction.fixBuild when canEditFiles => await _editAgent(
          projectPath,
        ).fixBuild(buildErrors, text),
        _ when selected.editsFiles && canEditFiles => await _editAgent(
          projectPath,
        ).edit(_withSelectedFile(text, projectPath), _history()),
        _ => await _ai.respond(selected, text, switch (selected) {
          AiAction.fixBuild => buildErrors.truncated(
            AppMetric.aiContextPreviewChars,
          ),
          _ when selected.isReview => await _reviewFindings(
            selected,
            projectPath!,
          ),
          _ => await _selectedFileContext(),
        }),
      };
      if (isStopped()) return;
      addReply(response.trim().isEmpty ? 'No suggestion available' : response);
      if (selected.isReview) {
        state = state.copyWith(action: AiAction.ask);
        addReply(
          'Switched to ${AiAction.ask.label}: say what to fix, e.g. '
          '"fix 1 and 3", and the changes are made in the files.',
          isProgress: true,
        );
      }
    } catch (e) {
      if (!isStopped()) addReply('Error: $e');
    } finally {
      if (!isStopped()) {
        _agent = null;
        state = state.copyWith(isBusy: false);
      }
    }
  }

  /// Appends [message].
  void _add(ChatMessage message) =>
      state = state.copyWith(messages: [...state.messages, message]);

  /// An agent that edits the project at [projectPath], reporting its steps
  /// in the chat, rebuilding for the platform selected in the Execute
  /// panel and running FIDE's quick fixes when the model asks; kept in
  /// [_agent] so [cancel] can stop it.
  CodeEditAgent _editAgent(String projectPath) {
    final buildService = _ref.read(flutterBuildServiceProvider);
    final target = _ref.read(selectedPlatformProvider).name;
    final lastBuildErrors = _ref.read(lastBuildErrorsProvider.notifier);
    final openDocuments = _ref.read(openDocumentsProvider.notifier);
    final quickFixes = _ref.read(quickFixRunnerProvider);
    return _agent = CodeEditAgent(
      _ai,
      projectPath: projectPath,
      hooks: CodeEditHooks(
        onStep: (step) => addReply('🔧 $step', isProgress: true),
        onFileWritten: (path) => openDocuments.reloadWritten([path]),
        // FIDE's own fixes, run without asking, for the model to call
        runQuickFix: (fix) async {
          try {
            final outcome = await quickFixes.run(
              projectPath,
              fix,
              onProgress: (step) => addReply(step, isProgress: true),
            );
            if (outcome == null) return '${fix.label} was cancelled.';
            await openDocuments.reloadWritten(outcome.changedFiles);
            _ref.invalidate(projectOverviewProvider);
            return outcome.summary;
          } on Exception catch (e) {
            return '${fix.label} failed: $e';
          }
        },
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

  /// The chat before the latest user message, without progress lines, as
  /// Ollama messages: the last [AppMetric.aiChatHistoryMessages], each cut
  /// to [AppMetric.aiMaxReadChars].
  List<Map<String, String>> _history() {
    final messages = state.messages;
    final earlier = messages
        .take(messages.length - 1)
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

  /// fcheck's findings for the project at [projectPath] that the review
  /// [action] needs, with the code they point to.
  Future<String> _reviewFindings(AiAction action, String projectPath) async {
    final review = _ref.read(codeReviewProvider);
    addReply('🔍 Analyzing the project with fcheck...', isProgress: true);
    final isDry = action == AiAction.dryReview;
    final metrics = await review.analyze(projectPath, nearDuplicates: isDry);
    return isDry ? review.duplicates(metrics) : review.design(metrics);
  }

  /// Content of the file open in the editor for the model, empty when
  /// none is.
  Future<String> _selectedFileContext() async {
    final file = _ref.read(selectedFileProvider);
    if (file == null) return '';
    try {
      return (await file.readAsString()).truncated(
        AppMetric.aiContextPreviewChars,
      );
    } catch (_) {
      return 'Could not read file content';
    }
  }

  /// [text] with the path of the file open in the editor, relative to
  /// [projectPath], so "this file" in the request can be resolved.
  String _withSelectedFile(String text, String projectPath) {
    final file = _ref.read(selectedFileProvider);
    if (file == null) return text;
    return '$text\n\n(The file open in the editor is '
        '${p.relative(file.path, from: projectPath)}.)';
  }
}
