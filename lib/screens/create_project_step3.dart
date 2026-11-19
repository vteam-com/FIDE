import 'package:fide/constants/constants.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/widget_services/loading_actions_progress.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The wizard's last step: the project being created and each creation
/// step's progress.
class CreateProjectStep3 extends ConsumerWidget {
  /// Creates the step.
  const CreateProjectStep3({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(createProjectDraftProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xLarge,
      children: [
        // Project info
        OutlinedSurface(
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
        const LoadingActionsProgress(
          failureMessage:
              'Project creation failed. Please check the errors above.',
        ),
      ],
    );
  }
}
