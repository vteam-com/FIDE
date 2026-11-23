import 'package:fide/services/chat_model.dart';
import 'package:flutter/foundation.dart';

/// A long task the app blocks for while it changes the project's files,
/// such as a quick fix or a refactoring: the step it is at, which the
/// blocking dialog shows, and the token its Cancel cancels.
///
/// A task checks [isCancelled] between its steps, before writing what a
/// step planned, so cancelling leaves no step half done: what is written
/// stays, the rest is never written.
class BlockingTask {
  /// Creates the task, at [step] first.
  BlockingTask(String step) : step = ValueNotifier(step);

  /// Cancelled when the user asks the task to stop.
  final AiCancelToken cancelToken = AiCancelToken();

  /// The step the task is at, in a few words: `Fixing camera_screen.dart`.
  final ValueNotifier<String> step;

  /// Whether the user asked the task to stop.
  bool get isCancelled => cancelToken.isCancelled;

  /// Asks the task to stop after its current step.
  void cancel() => cancelToken.cancel();

  /// Releases [step] once the task ended.
  void dispose() => step.dispose();

  /// Tells the dialog the task is now at [message].
  void report(String message) => step.value = message;
}
