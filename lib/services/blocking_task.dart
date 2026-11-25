import 'dart:async';

import 'package:fide/services/chat_model.dart';
import 'package:flutter/foundation.dart';

/// A long task the app blocks for while it changes the project's files,
/// such as a quick fix or a refactoring: the step it is at, which the
/// blocking dialog shows, and the token its Cancel cancels.
///
/// A task asks the user to confirm what it planned through [confirm],
/// which the same dialog shows in place of its progress, so the whole
/// task reads as one dialog: the plan, then the steps.
///
/// A task checks [isCancelled] between its steps, before writing what a
/// step planned, so cancelling leaves no step half done: what is written
/// stays, the rest is never written.
class BlockingTask {
  /// Creates the task, at [step] first; [confirmed] when the user already
  /// confirmed it, as pressing a fix under its findings does, so
  /// [confirm] asks nothing.
  BlockingTask(String step, {this.confirmed = false})
    : step = ValueNotifier(step);

  /// Whether the user confirmed the task before it started.
  final bool confirmed;

  /// The file the task is changing now, by absolute path; null between
  /// files.
  final ValueNotifier<String?> working = ValueNotifier(null);

  /// The files the task is done with, by absolute path, each true when it
  /// was changed, false when it was left as it was.
  final ValueNotifier<Map<String, bool>> finished = ValueNotifier(const {});

  /// Cancelled when the user asks the task to stop.
  final AiCancelToken cancelToken = AiCancelToken();

  /// The confirmation the task waits for, shown by the dialog in place of
  /// its progress; null while the task works.
  final ValueNotifier<BlockingQuestion?> question = ValueNotifier(null);

  /// The step the task is at, in a few words: `Fixing camera_screen.dart`.
  final ValueNotifier<String> step;

  /// Whether the user asked the task to stop.
  bool get isCancelled => cancelToken.isCancelled;

  /// Asks the task to stop after its current step.
  void cancel() => cancelToken.cancel();

  /// Asks the user to confirm [message] with [confirmLabel], the task
  /// paused meanwhile; resolves false on Cancel.
  Future<bool> confirm(String message, {required String confirmLabel}) {
    if (confirmed) return Future.value(true);
    final answer = Completer<bool>();
    question.value = (
      message: message,
      confirmLabel: confirmLabel,
      answer: answer,
    );
    return answer.future.whenComplete(() => question.value = null);
  }

  /// Answers the pending [question] with [confirmed].
  void answer({required bool confirmed}) {
    final pending = question.value?.answer;
    if (pending != null && !pending.isCompleted) pending.complete(confirmed);
  }

  /// Releases the notifiers once the task ended.
  void dispose() {
    step.dispose();
    question.dispose();
    working.dispose();
    finished.dispose();
  }

  /// Tells the dialog the task now changes the file at [path].
  void startFile(String path) => working.value = path;

  /// Tells the dialog the task is done with [paths], changed when
  /// [succeeded].
  void finishFiles(Iterable<String> paths, {required bool succeeded}) {
    working.value = null;
    finished.value = {
      ...finished.value,
      for (final path in paths) path: succeeded,
    };
  }

  /// Tells the dialog the task is now at [message].
  void report(String message) => step.value = message;
}

/// A confirmation a [BlockingTask] waits for: its [message], the label of
/// the button confirming it, and the [answer] the dialog completes.
typedef BlockingQuestion = ({
  String message,
  String confirmLabel,
  Completer<bool> answer,
});
