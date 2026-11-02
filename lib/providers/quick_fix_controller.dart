import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells the user [message], in [tone]'s meaning, such as a fix's outcome.
typedef QuickFixNotice = void Function(String message, StatusTone tone);

/// Provides the [QuickFixController] the issue rows run quick fixes with.
final quickFixControllerProvider = Provider<QuickFixController>(
  (ref) => QuickFixController(ref),
);

/// Runs the quick fixes the user picks on the open project: confirms
/// them, runs a fix asking the model as a task in the AI panel, reloads
/// the files they write, refreshes the project overview and reports the
/// outcome. The caller only provides the dialogs and messages.
class QuickFixController {
  /// Creates the controller reading the project and services through
  /// [_ref].
  QuickFixController(this._ref);

  /// Label of the action reviewing hardcoded strings.
  static const String reviewStringsLabel = 'Review strings';

  final Ref _ref;

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
    final projectPath = _ref.read(currentProjectPathProvider);
    if (projectPath == null) return;
    final runner = _ref.read(quickFixRunnerProvider);
    notify('$reviewStringsLabel…', StatusTone.info);
    final StringReview review;
    try {
      review = await runner.reviewStrings(projectPath);
    } catch (e) {
      notify('$reviewStringsLabel: $e', StatusTone.error);
      return;
    }
    final choice = await choose(review);
    if (choice == null) return;
    final fix = choice.fix;
    if (fix == null) {
      _ref.read(aiRequestsProvider).ask(review.aiRequest(choice.strings));
      return;
    }
    await _run(
      fix.quickFix,
      confirm: confirm,
      notify: notify,
      rewrite: (runner) => runner.applyStrings(review, fix, choice.strings),
    );
  }

  /// Runs [fix], or [rewrite] when given, as [apply] says.
  Future<void> _run(
    QuickFix fix, {
    required QuickFixConfirmation confirm,
    required QuickFixNotice notify,
    Future<QuickFixOutcome> Function(QuickFixRunner)? rewrite,
  }) async {
    final projectPath = _ref.read(currentProjectPathProvider);
    if (projectPath == null) return;
    final runner = _ref.read(quickFixRunnerProvider);
    final chat = _ref.read(aiChatProvider.notifier);
    if (fix.usesAi && _ref.read(aiChatProvider).isBusy) {
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
      _ref.read(aiRequestsProvider).showPanel();
      chat.beginTask(fix.label, cancel: cancel);
    }

    if (!fix.usesAi) notify('${fix.label}…', StatusTone.info);
    try {
      final outcome =
          await (rewrite?.call(runner) ??
              runner.run(
                projectPath,
                fix,
                confirm: (fix, message) async {
                  final confirmed = await confirm(fix, message);
                  if (confirmed) showInChat();
                  return confirmed;
                },
                onProgress: (step) => chat.addReply(step, isProgress: true),
                cancel: cancel,
              ));
      if (outcome == null) return;
      await _ref
          .read(openDocumentsProvider.notifier)
          .reloadWritten(outcome.changedFiles);
      _ref.invalidate(projectOverviewProvider);
      if (inChat) {
        chat.endTask(outcome.summary);
      } else {
        notify(outcome.summary, StatusTone.success);
      }
    } catch (e) {
      if (inChat) {
        chat.endTask('Error: $e');
      } else {
        notify('${fix.label}: $e', StatusTone.error);
      }
    }
  }
}
