import 'package:fide/constants/constants.dart';
import 'package:fide/models/create_project_step.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/screens/create_project_step1.dart';
import 'package:fide/screens/create_project_step2.dart';
import 'package:fide/screens/create_project_step3.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The new-project wizard: shows the current step of
/// [createProjectDraftProvider] between the title and the Cancel and
/// Next / Create / Open buttons.
class CreateProjectScreen extends ConsumerStatefulWidget {
  /// Parent folder offered when no default is configured.
  final String? initialDirectory;

  /// Leaves the wizard without creating anything.
  final VoidCallback onCancel;

  /// Opens the created project, given its path.
  final void Function(String) onOpenProject;

  /// Creates the wizard.
  const CreateProjectScreen({
    super.key,
    this.initialDirectory,
    required this.onOpenProject,
    required this.onCancel,
  });

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  @override
  void initState() {
    super.initState();
    // After the first build: providers can't change while widgets build
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(createProjectDraftProvider.notifier)
          .resolveParentDirectory(widget.initialDirectory);
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createProjectDraftProvider);
    if (draft.parentDirectory == null) {
      return const Scaffold(body: LoadingIndicator());
    }
    final projectPath = draft.projectPath;
    final notifier = ref.read(createProjectDraftProvider.notifier);
    final (label, onPressed) = switch (draft.step) {
      CreateProjectStep.nameAndFolder => (
        'Next',
        draft.canLeaveDetails ? notifier.next : null,
      ),
      CreateProjectStep.localization => ('Create', notifier.next),
      CreateProjectStep.creating => (
        'Open',
        draft.created && projectPath != null
            ? () => widget.onOpenProject(projectPath)
            : null,
      ),
    };

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(AppSpacing.huge),
        decoration: AppTheme.screenBackground(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroTitleWidget(
              title: 'New Flutter Project',
              subWidget: projectPath != null
                  ? PathText(
                      projectPath,
                      selectable: true,
                      style: AppTextStyle.label,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.huge),
            Expanded(child: _stepContent(draft.step)),
            Container(
              padding: const EdgeInsets.only(top: AppSpacing.xxLarge),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: AppPadding.wizardButton,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.xLarge),
                  FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      padding: AppPadding.wizardButton,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The page of [step]; the form steps scroll within the wizard's width.
  static Widget _stepContent(CreateProjectStep step) {
    final Widget form;
    switch (step) {
      case CreateProjectStep.nameAndFolder:
        form = const CreateProjectStep1();
      case CreateProjectStep.localization:
        form = const CreateProjectStep2();
      case CreateProjectStep.creating:
        return const Center(child: CreateProjectStep3());
    }
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.wizardMaxWidth),
          child: form,
        ),
      ),
    );
  }
}
