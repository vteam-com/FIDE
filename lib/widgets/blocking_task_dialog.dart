import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/blocking_task.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:material_ui/material_ui.dart';

/// The dialog blocking the app, over a scrim, while a task changes the
/// project's files, so nothing else edits them meanwhile: the task's
/// [title], the step it is at under a [BusyBar], and Cancel, which asks
/// the task to stop after its current step. Nothing dismisses it but the
/// task ending.
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
      // Dialogs the task opened, such as its confirmation, may be above
      if (route.isActive) navigator.removeRoute(route);
      task.dispose();
    }
  }
}

class _BlockingTaskDialogState extends State<BlockingTaskDialog> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: AppSize.cardWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.medium,
            children: [
              const BusyBar(),
              ValueListenableBuilder(
                valueListenable: task.step,
                builder: (context, step, _) =>
                    Text(step, style: AppTextStyle.secondary(context)),
              ),
            ],
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: task.isCancelled ? null : _cancel,
          ),
        ],
      ),
    );
  }

  /// Asks the task to stop, telling so until it does.
  void _cancel() {
    widget.task
      ..cancel()
      ..report(BlockingTaskDialog.cancellingStep);
    setState(() {});
  }
}
