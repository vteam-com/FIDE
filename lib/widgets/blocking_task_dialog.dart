import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/blocking_task.dart';
import 'package:fide/widgets/blocking_task_progress.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:material_ui/material_ui.dart';

/// The dialog blocking the app, over a scrim, while a task changes the
/// project's files, so nothing else edits them meanwhile: the task's
/// [title], then, in the same frame, the confirmation the task asks
/// ([BlockingTask.confirm]) and the step it is at under a [BusyBar], with
/// Cancel, which asks the task to stop after its current step. As wide as
/// the issue details opening it, so a fix reads as one dialog going from
/// the problem to the plan to the steps. Nothing dismisses it but the task
/// ending.
class BlockingTaskDialog extends StatefulWidget {
  /// Creates the dialog of [task], titled [title].
  const BlockingTaskDialog({
    super.key,
    required this.title,
    required this.task,
  });

  /// The step shown once Cancel was pressed, until the task stops.
  static const String cancellingStep = 'Cancelling after this step…';

  /// The task running.
  final BlockingTask task;

  /// What the task does, as its action's name: `Fix States`.
  final String title;

  @override
  State<BlockingTaskDialog> createState() => _BlockingTaskDialogState();

  /// Runs [run] with the app blocked by the dialog, over [context], titled
  /// [title], at [step] first; returns what [run] returns, the dialog gone
  /// however [run] ends. Without [context] mounted, [run] runs unblocked.
  static Future<T> run<T>(
    BuildContext context, {
    required String title,
    required String step,
    required Future<T> Function(BlockingTask task) run,
  }) async {
    final task = BlockingTask(step);
    if (!context.mounted) return run(task);
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlockingTaskDialog(title: title, task: task),
    );
    unawaited(navigator.push(route));
    try {
      return await run(task);
    } finally {
      // Dialogs the task opened may be above
      if (route.isActive) navigator.removeRoute(route);
      task.dispose();
    }
  }

  /// [message] cut after its question: the question, and what follows it,
  /// empty when it asks nothing or nothing follows.
  static (String, String) splitQuestion(String message) {
    const mark = '? ';
    final end = message.indexOf(mark);
    if (end < 0) return (message, '');
    return (
      message.substring(0, end + 1),
      message.substring(end + mark.length).trim(),
    );
  }
}

class _BlockingTaskDialogState extends State<BlockingTaskDialog> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return PopScope(
      canPop: false,
      child: ValueListenableBuilder(
        valueListenable: task.question,
        builder: (context, question, _) => AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: AppSize.issueDetailsWidth,
            child: question == null
                ? BlockingTaskProgress(task)
                : _question(context, question.message),
          ),
          actions: [
            SecondaryButton(
              label: 'Cancel',
              onPressed: task.isCancelled ? null : _cancel,
            ),
            if (question != null)
              PrimaryButton(
                label: question.confirmLabel,
                onPressed: () => task.answer(confirmed: true),
              ),
          ],
        ),
      ),
    );
  }

  /// Asks the task to stop, telling so until it does; declines its
  /// pending confirmation.
  void _cancel() {
    widget.task
      ..cancel()
      ..answer(confirmed: false)
      ..report(BlockingTaskDialog.cancellingStep);
    setState(() {});
  }

  /// The task's confirmation: its question first, the explanation
  /// following it dimmed under it.
  Widget _question(BuildContext context, String message) {
    final (question, detail) = BlockingTaskDialog.splitQuestion(message);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        Text(question),
        if (detail.isNotEmpty)
          Text(detail, style: AppTextStyle.secondary(context)),
      ],
    );
  }
}
