import 'dart:async';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/ai_chat.dart';
import 'package:fide/models/chat_message.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/models/prompt_intent.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/ai_assistant.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/code_edit_agent.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/dart_analyzer.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/services/project_command_service.dart';
import 'package:fide/services/project_file_store.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

/// The AI panel's conversation, which outlives the panel: hiding it or
/// switching tabs keeps the messages, and a pending reply or task still
/// lands in the chat.
final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChat>(
  (ref) => AiChatNotifier(
    model: ref.watch(chatModelProvider),
    analyzer: ref.watch(dartAnalyzerProvider),
    assistant: ref.watch(aiAssistantProvider),
    review: ref.watch(codeReviewProvider),
    quickFixes: ref.watch(quickFixRunnerProvider),
    latest: ref.watch(savedCodeMetricsProvider),
    builds: ref.watch(flutterBuildServiceProvider),
    commands: ref.watch(projectCommandServiceProvider),
    reader: ref.watch(fileContentReaderProvider),
    documents: ref.watch(openDocumentsProvider.notifier),
    projectPath: () => ref.read(currentProjectPathProvider),
    selectedFile: () => ref.read(selectedFileProvider),
    platform: () => ref.read(selectedPlatformProvider),
    buildErrors: () => ref.read(lastBuildErrorsProvider),
    onBuildErrors: (errors) =>
        ref.read(lastBuildErrorsProvider.notifier).state = errors,
  ),
);

/// Runs the AI panel's conversation: sends prompts for the selected
/// action, lets the agent edit files, shows tasks such as Translate with
/// AI, and stops whatever is pending.
class AiChatNotifier extends StateNotifier<AiChat> {
  /// Creates an empty conversation.
  ///
  /// Prompts go to [_model], through [_assistant] for suggestions and
  /// reviews (analyzed with [_review], unless [_latest] has an analysis
  /// of the current files) or through an agent that edits the
  /// project [_projectPath] gives, when the model can call tools; the
  /// agent reads files with [_reader], reloads the ones it writes in
  /// [_documents], runs [_quickFixes] and the commands it asks for with
  /// [_commands], and checks its work with [_analyzer],
  /// and when fixing a build, with [_builds] for the [_platform] selected,
  /// keeping [_buildErrors] up to date through [_onBuildErrors];
  /// [_selectedFile] gives the file open in the editor. Reloading written
  /// files re-analyzes the project.
  AiChatNotifier({
    required this._model,
    required this._analyzer,
    required this._assistant,
    required this._review,
    required this._quickFixes,
    required this._builds,
    required this._commands,
    required this._reader,
    required this._documents,
    required this._projectPath,
    required this._selectedFile,
    required this._platform,
    required this._buildErrors,
    required this._onBuildErrors,
    this._latest,
  }) : super(const AiChat());

  /// The overview's analysis of the project's current files, reused by
  /// the reviews analyzing with the same settings.
  final LatestCodeMetrics? _latest;

  final DartAnalyzer _analyzer;

  final AiAssistant _assistant;

  final String Function() _buildErrors;

  final FlutterBuildService _builds;

  final ProjectCommandService _commands;

  /// Stops the pending reply or task's model requests, if any.
  AiCancelToken? _cancelToken;

  final OpenDocumentsNotifier _documents;

  /// The reply streaming in, shown at most every
  /// [AppDuration.outputLogPublish].
  String _draft = '';

  /// Shows [_draft] once it fires; null while nothing waits to show.
  Timer? _draftTimer;

  final ChatModel _model;

  final void Function(String errors) _onBuildErrors;

  final FlutterPlatform Function() _platform;

  final String? Function() _projectPath;

  final QuickFixRunner _quickFixes;

  final FileContentReader _reader;

  /// Bumped per request and by [cancel], so a stopped request's late
  /// reply is dropped.
  int _requestId = 0;

  final CodeReview _review;

  final FileSystemItem? Function() _selectedFile;

  /// Whether a reply or task is pending.
  bool get isBusy => state.isBusy;

  /// Adds a model message showing [content], in place of the reply
  /// streaming in; [isProgress] keeps it out of the history sent to the
  /// model.
  void addReply(String content, {bool isProgress = false}) {
    _clearDraft();
    _add(
      ChatMessage(
        content: content,
        isUser: false,
        isProgress: isProgress,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Shows a task named [label], such as a quick fix, as the user's
  /// request and marks the chat busy until [endTask]; [cancel] stops its
  /// model requests.
  void beginTask(String label, {AiCancelToken? cancel}) {
    _requestId++;
    _cancelToken = cancel;
    _add(ChatMessage(content: label, isUser: true, timestamp: DateTime.now()));
    state = state.copyWith(isBusy: true);
  }

  /// Stops the pending reply or task: aborts its model requests and the
  /// agent's edits, and frees the input for the next prompt. Other
  /// features' model requests, such as a commit message, go on.
  void cancel() {
    if (!state.isBusy) return;
    _cancelToken?.cancel();
    _cancelToken = null;
    _requestId++;
    state = state.copyWith(isBusy: false);
    addReply('⏹ Stopped.', isProgress: true);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    super.dispose();
  }

  /// Ends the task [beginTask] started with its outcome, [reply].
  void endTask(String reply) {
    addReply(reply);
    state = state.copyWith(isBusy: false);
  }

  /// Makes [action] the one new prompts use.
  void selectAction(AiAction action) => state = state.copyWith(action: action);

  /// Gets the model ready to answer, so the next prompt doesn't wait for a
  /// local model to load.
  Future<void> warmUp() => _model.warmUp();

  /// Sends [text] for the selected action, or [action] when given, and
  /// shows the reply; ignored while a reply is pending.
  ///
  /// Actions that [AiAction.editsFiles] change the open project's files
  /// themselves, with the earlier chat as context; Ask AI only when the
  /// prompt asks for a change ([PromptIntent.asksForChange]), answering
  /// any other prompt while reading, not changing, the code. With no
  /// project open, or a model that can't call tools, they only suggest
  /// changes. After a
  /// review the chat switches to Ask AI, so the next message, like "fix
  /// 1", acts on the review.
  Future<void> send(String text, {AiAction? action}) async {
    if (state.isBusy) return;
    final selected = action ?? state.action;
    final buildErrors = _buildErrors();
    final projectPath = _projectPath();
    // Actions sending build errors need no prompt when the last build left
    // some; reviews send fcheck's findings
    final sendsBuildErrors = selected.context == AiContext.buildErrors;
    final canSendEmpty =
        (sendsBuildErrors && buildErrors.isNotEmpty) || selected.isReview;
    if (text.isEmpty && !canSendEmpty) return;

    final requestId = ++_requestId;
    bool isStopped() => requestId != _requestId;
    final cancel = _cancelToken = AiCancelToken();
    _add(
      ChatMessage(
        content: text.isEmpty ? selected.label : text,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    state = state.copyWith(action: selected, isBusy: true);

    // Ask AI edits only prompts asking for a change, as code reads them:
    // a local model given editing tools edits files even for "2+2="
    final asksForChange =
        selected.editsFiles &&
        (!selected.editsOnlyWhenAsked || PromptIntent.asksForChange(text));
    // Models without tool calling can only suggest changes
    final canUseTools = projectPath != null && _model.supportsTools;
    if (asksForChange && projectPath != null && !canUseTools) {
      addReply(
        "${_model.name} can't call tools, so it can only suggest changes. "
        'Download ${AiModel.ollama} to let it edit files.',
        isProgress: true,
      );
    }

    try {
      if (selected.isReview && projectPath == null) {
        addReply('Open a project to review it.');
        return;
      }
      final String response;
      if (selected.editsFiles && canUseTools) {
        final agent = _editAgent(
          projectPath,
          cancel,
          checksWithBuild: sendsBuildErrors,
        );
        response = sendsBuildErrors
            ? await agent.fixBuild(buildErrors, text)
            : asksForChange
            ? await agent.edit(_withSelectedFile(text, projectPath), _history())
            // A question names the open file only when it points at it
            : await agent.answer(
                PromptIntent.refersToOpenFile(text)
                    ? _withSelectedFile(text, projectPath)
                    : text,
                _history(),
              );
      } else {
        response = await _assistant.respond(
          selected,
          text,
          await _context(selected.context, projectPath),
          cancel: cancel,
          onText: _showDraft,
        );
      }
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
      if (!isStopped()) addReply('Error: ${ReadableError.describe(e)}');
    } finally {
      if (!isStopped()) {
        _cancelToken = null;
        _clearDraft();
        state = state.copyWith(isBusy: false);
      }
    }
  }

  /// Appends [message].
  void _add(ChatMessage message) =>
      state = state.copyWith(messages: [...state.messages, message]);

  /// Shows no reply streaming in.
  void _clearDraft() {
    _draftTimer?.cancel();
    _draftTimer = null;
    _draft = '';
    if (state.draft.isNotEmpty) state = state.copyWith(draft: '');
  }

  /// Shows [text] as the reply streaming in, at most every
  /// [AppDuration.outputLogPublish], so a fast model doesn't rebuild the
  /// panel for each word.
  void _showDraft(String text) {
    _draft = text;
    _draftTimer ??= Timer(AppDuration.outputLogPublish, () {
      _draftTimer = null;
      if (mounted) state = state.copyWith(draft: _draft);
    });
  }

  /// The compile errors of the project at [projectPath], one
  /// `path:line: message` per line, empty when there are none, as
  /// `dart analyze` finds them in seconds where a build takes minutes.
  /// When [build] is set, as when fixing a failed build whose errors may
  /// lie outside Dart, a project the analyzer finds no error in is built
  /// for [platform], its errors kept through [_onBuildErrors]; so is one
  /// the analyzer can't check. [cancel] stops the analysis.
  Future<String> _compileErrors(
    String projectPath,
    FlutterPlatform platform,
    AiCancelToken cancel, {
    required bool build,
  }) async {
    try {
      final analysis = await _analyzer.analyze(
        projectPath,
        stop: cancel.whenCancelled,
      );
      final errors = [
        for (final diagnostic in analysis.diagnostics)
          if (diagnostic.tone == StatusTone.error)
            '${p.relative(diagnostic.path, from: projectPath)}:'
                '${diagnostic.line}: ${diagnostic.message}',
      ];
      if (errors.isNotEmpty || !build) return errors.join('\n');
    } on Exception {
      // The build tells, unless the analysis was stopped
      cancel.throwIfCancelled();
    }
    final log = OutputLog();
    final exitCode = await _builds.build(
      projectPath,
      platform,
      BuildOutput(onOutput: log.addOutput, onError: log.addError),
    );
    final buildErrors = exitCode == 0
        ? ''
        : (log.hasErrors ? log.errors : log.output);
    _onBuildErrors(buildErrors);
    return buildErrors;
  }

  /// An agent that edits the project at [projectPath], reporting its steps
  /// and its replies as they stream in the chat, checking its work for
  /// compile errors, with a build for the platform selected in the Execute
  /// panel when [checksWithBuild] is set, and running FIDE's quick fixes
  /// and the commands it allows when the model asks; [cancel] stops it and
  /// the fixes and commands it runs.
  CodeEditAgent _editAgent(
    String projectPath,
    AiCancelToken cancel, {
    required bool checksWithBuild,
  }) {
    final platform = _platform();
    return CodeEditAgent(
      _model,
      files: ProjectFileStore(projectPath, reader: _reader),
      cancelToken: cancel,
      hooks: CodeEditHooks(
        onStep: (step) => addReply(step, isProgress: true),
        onText: _showDraft,
        onFileWritten: (path) => _documents.reloadWritten([path]),
        // FIDE's own fixes, run without asking, for the model to call
        runQuickFix: (fix) async {
          try {
            final outcome = await _quickFixes.run(
              projectPath,
              fix,
              onProgress: (step) => addReply(step, isProgress: true),
              cancel: cancel,
            );
            if (outcome == null) return '${fix.label} was cancelled.';
            await _documents.reloadWritten(outcome.changedFiles);
            return outcome.summary;
          } on Exception catch (e) {
            return '${fix.label} failed: ${ReadableError.describe(e)}';
          }
        },
        // The files a command changes reload like those the agent writes
        runCommand: (command, directory) async {
          final outcome = await _commands.run(
            command,
            projectPath: projectPath,
            directory: directory,
            stop: cancel.whenCancelled,
          );
          if (outcome.changedFiles.isNotEmpty) {
            await _documents.reloadWritten(outcome.changedFiles);
          }
          return outcome.summary;
        },
        checkBuild: () => _compileErrors(
          projectPath,
          platform,
          cancel,
          build: checksWithBuild,
        ),
      ),
    );
  }

  /// The chat before the latest user message, without progress lines, as
  /// `role`/`content` messages: at most the last
  /// [AppMetric.aiChatHistoryMessages], the latest kept first, until
  /// [AppMetric.aiHistoryChars] are spent, the one that overflows cut;
  /// starting with the user's, as models expect.
  List<Map<String, String>> _history() {
    final messages = state.messages;
    final earlier = messages
        .take(messages.length - 1)
        .where((message) => !message.isProgress);
    final kept = <({bool isUser, String content})>[];
    var room = AppMetric.aiHistoryChars;
    for (final message in earlier.toList().reversed.take(
      AppMetric.aiChatHistoryMessages,
    )) {
      if (room <= 0) break;
      final content = message.content.truncated(room);
      room -= content.length;
      kept.insert(0, (isUser: message.isUser, content: content));
    }
    final start = kept.indexWhere((message) => message.isUser);
    return [
      if (start >= 0)
        for (final message in kept.skip(start))
          {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
          },
    ];
  }

  /// What [context] sends the model for the project at [projectPath],
  /// which a review needs.
  Future<String> _context(AiContext context, String? projectPath) async =>
      switch (context) {
        AiContext.none => '',
        AiContext.selectedFile => await _selectedFileContext(),
        AiContext.buildErrors => _buildErrors().truncated(
          AppMetric.aiContextPreviewChars,
        ),
        AiContext.duplicates => await _reviewFindings(
          projectPath!,
          const ReviewFindings().duplicates,
          nearDuplicates: true,
        ),
        AiContext.design => await _reviewFindings(
          projectPath!,
          const ReviewFindings().design,
        ),
      };

  /// fcheck's findings for the project at [projectPath], written by
  /// [write] with the code they point to; [nearDuplicates] also finds code
  /// that was copied and has since drifted.
  Future<String> _reviewFindings(
    String projectPath,
    Future<String> Function(fcheck.ProjectMetrics) write, {
    bool nearDuplicates = false,
  }) async {
    addReply('🔍 Analyzing the project with fcheck…', isProgress: true);
    // Near duplicates need their own settings; the others reuse the
    // overview's analysis while no file changed since
    final latest = nearDuplicates ? null : await _latest?.call(projectPath);
    return write(
      latest ??
          await _review.analyze(projectPath, nearDuplicates: nearDuplicates),
    );
  }

  /// Content of the file open in the editor for the model, empty when
  /// none is.
  Future<String> _selectedFileContext() async {
    final file = _selectedFile();
    if (file == null) return '';
    try {
      return (await _reader.read(file.path))
          .truncated(AppMetric.aiContextPreviewChars);
    } catch (_) {
      return 'Could not read file content';
    }
  }

  /// [text] with the path of the file open in the editor, relative to
  /// [projectPath], so "this file" in the request can be resolved.
  String _withSelectedFile(String text, String projectPath) {
    final file = _selectedFile();
    if (file == null) return text;
    return '$text\n\n(The file open in the editor is '
        '${p.relative(file.path, from: projectPath)}.)';
  }
}
