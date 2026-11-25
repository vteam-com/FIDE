import 'package:fide/constants/constants.dart';
import 'package:fide/services/blocking_task.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The step a [BlockingTask] is at under a [BusyBar]: its one progress
/// indicator, in the dialog blocking the app and in the issue details a
/// fix runs in alike.
class BlockingTaskProgress extends StatelessWidget {
  /// Creates the progress of [task].
  const BlockingTaskProgress(this.task, {super.key});

  /// The task running.
  final BlockingTask task;

  @override
  Widget build(BuildContext context) => Column(
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
  );
}
