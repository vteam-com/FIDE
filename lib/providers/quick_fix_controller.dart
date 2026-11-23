import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells the user [message], in [tone]'s meaning, such as a fix's outcome.
typedef QuickFixNotice = void Function(String message, StatusTone tone);

/// Provides the [QuickFixController] the issue rows run quick fixes with.
final quickFixControllerProvider = Provider<QuickFixController>(
  (ref) => QuickFixController(
    projectPath: () => ref.read(currentProjectPathProvider),
    runner: ref.watch(quickFixRunnerProvider),
    chat: ref.watch(aiChatProvider.notifier),
    requests: ref.watch(aiRequestsProvider),
    documents: ref.watch(openDocumentsProvider.notifier),
    translator: ref.read(arbTranslatorProvider),
  ),
);

/// Runs the quick fixes the user picks on the open project: confirms
/// them, runs a fix asking the model as a task in the AI panel, reloads
/// the files they write, which re-analyzes the project, and reports the
/// outcome. The caller only provides the dialogs and messages.
class QuickFixController {
  /// Creates the controller running fixes with [_runner] on the project
  /// [_projectPath] gives, showing those asking the model in [_chat] and
  /// sending the strings no fix can rewrite through [_requests] and
  /// translating one key with [_translator]; the files a fix writes are
  /// reloaded in [_documents], which re-analyzes the project.
  QuickFixController({
    required this._projectPath,
    required this._runner,
    required this._chat,
    required this._requests,
    required this._documents,
    required this._translator,
  });

  /// Label of the action reviewing hardcoded strings.
  static const String reviewStringsLabel = 'Review strings';

  final AiChatNotifier _chat;

  final OpenDocumentsNotifier _documents;

  final String? Function() _projectPath;

  final AiRequests _requests;

  final QuickFixRunner _runner;

  final ArbTranslator _translator;

  /// Applies [fix] to the open project once the user confirms it through
  /// [confirm], telling [notify] the outcome; a fix asking the model runs
  /// as a task in the AI panel, with its progress. Does nothing without a
  /// project.
  Future<void> apply(
    QuickFix fix, {
    required QuickFixConfirmation confirm,
    required QuickFixNotice notify,
  }) => _run(fix, confirm: confirm, notify: notify);

  /// Has [choose] show the open project's hardcoded strings grouped by
  /// role and applies the fix the user picks, or has the AI rewrite the
  /// strings no fix can; [confirm] and [notify] as for [apply]. Does
  /// nothing without a project.
  Future<void> reviewStrings({
    required Future<StringReviewChoice?> Function(StringReview review) choose,
    required QuickFixConfirmation confirm,
    required QuickFixNotice notify,
  }) async {
    final projectPath = _projectPath();
    if (projectPath == null) return;
    notify('$reviewStringsLabel…', StatusTone.info);
    final StringReview review;
    try {
      review = await _runner.reviewStrings(projectPath);
    } catch (e) {
      notify(
        '$reviewStringsLabel: ${ReadableError.describe(e)}',
        StatusTone.error,
      );
      return;
    }
    final choice = await choose(review);
    if (choice == null) return;
    final fix = choice.fix;
    if (fix == null) {
      _requests.ask(review.aiRequest(choice.strings));
      return;
    }
    await _run(
      fix.quickFix,
      confirm: confirm,
      notify: notify,
      rewrite: (_, _) => _runner.applyStrings(review, fix, choice.strings),
    );
  }

  /// Translates [translations], the keys and languages the user picked,
  /// as [QuickFix.translateKeys] does every key: a task in the AI panel,
  /// which its Stop cancels, once the AI is free; [notify] says when it
  /// isn't. Does nothing without a project.
  Future<void> translate(
    List<ArbTranslation> translations, {
    required QuickFixNotice notify,
  }) => _run(
    QuickFix.translateKeys,
    // The keys and languages the user picked: nothing to confirm
    confirm: (_, _) async => true,
    notify: notify,
    rewrite: (projectPath, cancel) async {
      final result = await _translator.apply(
        projectPath,
        translations,
        onProgress: (step) => _chat.addReply(step, isProgress: true),
        cancel: cancel,
      );
      return (summary: result.summary, changedFiles: result.changedFiles);
    },
  );

  /// Runs [fix], or [rewrite] of the project with the task's cancel token
  /// when given, as [apply] says.
  Future<void> _run(
    QuickFix fix, {
    required QuickFixConfirmation confirm,
    required QuickFixNotice notify,
    Future<QuickFixOutcome> Function(String projectPath, AiCancelToken cancel)?
    rewrite,
  }) async {
    final projectPath = _projectPath();
    if (projectPath == null) return;
    if (fix.usesAi && _chat.isBusy) {
      notify('The AI is busy: wait for it or stop it', StatusTone.error);
      return;
    }

    // A fix asking the model runs as a task in the AI panel once confirmed,
    // which the panel's Stop button cancels
    final cancel = AiCancelToken();
    var inChat = false;
    void showInChat() {
      if (!fix.usesAi || inChat) return;
      inChat = true;
      _requests.showPanel();
      _chat.beginTask(fix.label, cancel: cancel);
    }

    if (!fix.usesAi) notify('${fix.label}…', StatusTone.info);
    // A rewrite runs unasked: the user picked what it rewrites
    if (rewrite != null) showInChat();
    try {
      final outcome =
          await (rewrite?.call(projectPath, cancel) ??
              _runner.run(
                projectPath,
                fix,
                confirm: (fix, message) async {
                  final confirmed = await confirm(fix, message);
                  if (confirmed) showInChat();
                  return confirmed;
                },
                onProgress: (step) => _chat.addReply(step, isProgress: true),
                cancel: cancel,
              ));
      if (outcome == null) return;
      await _documents.reloadWritten(outcome.changedFiles);
      if (inChat) {
        _chat.endTask(outcome.summary);
      } else {
        // A fix that wrote nothing found nothing to do: no success
        notify(
          outcome.summary,
          outcome.changedFiles.isEmpty ? StatusTone.info : StatusTone.success,
        );
      }
    } catch (e) {
      if (inChat) {
        _chat.endTask('Error: ${ReadableError.describe(e)}');
      } else {
        notify('${fix.label}: ${ReadableError.describe(e)}', StatusTone.error);
      }
    }
  }
}
