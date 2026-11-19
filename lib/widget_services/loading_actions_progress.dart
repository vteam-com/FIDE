import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/loading_actions_log.dart';
import 'package:fide/widgets/loading_progress_bar.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The progress of the steps [loadingActionsProvider] reports, such as a
/// project loading or being created: the bar, the log of each step, then
/// [failureMessage] once a step has failed.
class LoadingActionsProgress extends ConsumerWidget {
  /// Creates the progress view, telling [failureMessage] on a failure.
  const LoadingActionsProgress({super.key, required this.failureMessage});

  /// Shown under the log, in the error color, once a step has failed.
  final String failureMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(loadingActionsProvider);
    final hasFailed = actions.any(
      (action) => action.status == LoadingStatus.failed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xLarge,
      children: [
        LoadingProgressBar(actions: actions),
        if (actions.isNotEmpty) LoadingActionsLog(actions: actions),
        if (hasFailed)
          Text(
            failureMessage,
            style: AppTextStyle.label.copyWith(
              color: StatusTone.error.readableIn(Theme.of(context).colorScheme),
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
