import 'package:fide/models/create_project_draft.dart';
import 'package:fide/models/create_project_step.dart';
import 'package:fide/models/creation_outcome.dart';
import 'package:fide/models/creation_report.dart';
import 'package:fide/models/creation_step.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/tool_availability_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'create_project_draft_notifier.creation_labels.dart';

/// The new-project wizard's draft, fresh on every visit.
final createProjectDraftProvider =
    NotifierProvider.autoDispose<
      CreateProjectDraftNotifier,
      CreateProjectDraft
    >(CreateProjectDraftNotifier.new);

/// Holds the new-project wizard's choices, its language rules and its
/// steps, and runs creation from the last one.
class CreateProjectDraftNotifier extends Notifier<CreateProjectDraft> {
  @override
  CreateProjectDraft build() {
    // Keep the probes for creation once step 1 no longer watches them
    ref.listen(toolAvailabilityProvider, (_, _) {});
    return const CreateProjectDraft();
  }

  /// Sets the project name as typed.
  void setName(String name) => state = state.copyWith(name: name);

  /// Sets the folder the project is created in.
  void setParentDirectory(String directory) =>
      state = state.copyWith(parentDirectory: directory);

  /// Fills in the parent folder unless one is set: the configured
  /// default, else [initialDirectory], else the documents folder.
  Future<void> resolveParentDirectory(String? initialDirectory) async {
    final directory =
        ref.read(newProjectParentDirectoryProvider) ??
        initialDirectory ??
        (await ref.read(documentsDirectoryProvider)()).path;
    if (ref.mounted && state.parentDirectory == null) {
      setParentDirectory(directory);
    }
  }

  /// Turns AI generation on or off.
  void setUseAi(bool useAi) => state = state.copyWith(useAi: useAi);

  /// Sets what the app should do, for AI generation.
  void setDescription(String description) =>
      state = state.copyWith(description: description);

  /// Turns localization on or off.
  void setWantsLocalization(bool wants) =>
      state = state.copyWith(wantsLocalization: wants);

  /// Adds or removes [language]; removing the default language makes the
  /// first remaining one the default, and removing the last one brings
  /// back the initial language.
  void setLanguage(String language, {required bool selected}) {
    final languages = {...state.languages};
    if (selected) {
      languages.add(language);
    } else {
      languages.remove(language);
    }
    if (languages.isEmpty) languages.add(CreateProjectDraft.initialLanguage);
    state = state.copyWith(
      languages: languages,
      defaultLanguage: languages.contains(state.defaultLanguage)
          ? state.defaultLanguage
          : languages.first,
    );
  }

  /// Makes [language] the generated app's default.
  void setDefaultLanguage(String language) =>
      state = state.copyWith(defaultLanguage: language);

  /// Goes to the next step when the current one allows it; leaving the
  /// localization step starts creation.
  Future<void> next() async {
    switch (state.step) {
      case CreateProjectStep.nameAndFolder:
        if (state.canLeaveDetails) {
          state = state.copyWith(step: CreateProjectStep.localization);
        }
      case CreateProjectStep.localization:
        state = state.copyWith(step: CreateProjectStep.creating);
        await _create();
      case CreateProjectStep.creating:
        break;
    }
  }

  /// Creates the project, publishing each step's progress to
  /// [loadingActionsProvider] and marking the draft created on success.
  Future<void> _create() async {
    final actions = ref.read(loadingActionsProvider.notifier);
    actions.state = CreationLabels.initialActions();
    final tools = await ref.read(toolAvailabilityProvider.future);
    if (!ref.mounted) return;
    final created = await ref.read(projectCreationServiceProvider).create(
      state.toRequest(tools),
      (report) {
        final number = report.step.number;
        actions.state = [
          for (final action in actions.state)
            action.step == number
                ? LoadingAction(
                    number,
                    CreationLabels.of(report),
                    report.status,
                  )
                : action,
        ];
      },
    );
    if (created && ref.mounted) state = state.copyWith(created: true);
  }
}
