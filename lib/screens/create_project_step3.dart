import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/widgets/loading_actions_log.dart';
import 'package:fide/widgets/loading_progress_bar.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wizard's last step: the project being created and each creation
/// step's progress.
class CreateProjectStep3 extends ConsumerWidget {
  /// Creates the step.
  const CreateProjectStep3({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(createProjectDraftProvider);
    final loadingActions = ref.watch(loadingActionsProvider);
    final hasFailed = loadingActions.any(
      (action) => action.status == LoadingStatus.failed,
    );

    return Container(
      width: AppSize.panelFallbackHeight,
      constraints: const BoxConstraints(maxHeight: AppSize.terminalMaxHeight),
      child: Column(
        spacing: AppSpacing.xLarge,
        children: [
          // Project info
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.medium,
              children: [
                SectionTitle('Creating project: ${draft.packageName}'),
                PathText(
                  draft.projectPath ?? '',
                  selectable: true,
                  style: AppTextStyle.label,
                ),
              ],
            ),
          ),

          LoadingProgressBar(actions: loadingActions),

          if (loadingActions.isNotEmpty)
            Expanded(
              child: LoadingActionsLog(actions: loadingActions, framed: true),
            ),

          // Error message if failed
          if (hasFailed)
            Text(
              'Project creation failed. Please check the errors above.',
              style: AppTextStyle.label.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
