import 'package:fide/constants/constants.dart';
import 'package:fide/models/language_catalog.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/widgets/locale_badges.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/step_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The wizard's second step: whether to localize, which languages and the
/// default one, kept in [createProjectDraftProvider].
class CreateProjectStep2 extends ConsumerWidget {
  /// Creates the step.
  const CreateProjectStep2({super.key});

  /// This step's place in the wizard.
  static const int _stepNumber = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(createProjectDraftProvider);
    final notifier = ref.read(createProjectDraftProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xxLarge,
      children: [
        StepHeader(number: _stepNumber, title: 'Localization Settings'),

        const SizedBox(height: AppSpacing.xLarge),

        // Project summary
        OutlinedSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.medium,
            children: [
              SectionTitle('Project: ${draft.packageName}'),
              Text(
                'Location: ${draft.parentDirectory}',
                style: AppTextStyle.caption,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xLarge),

        const SectionTitle('Do you want to localize your app?'),

        RadioGroup<bool>(
          groupValue: draft.wantsLocalization,
          onChanged: (value) => notifier.setWantsLocalization(value!),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Yes'),
                subtitle: const Text('Support multiple languages'),
                value: true,
              ),
              RadioListTile<bool>(
                title: const Text('No'),
                subtitle: const Text('Use default language only'),
                value: false,
              ),
            ],
          ),
        ),

        if (draft.wantsLocalization) ...[
          const SizedBox(height: AppSpacing.xLarge),

          const SectionTitle('Select languages to support'),

          LocaleBadges(
            locales: draft.languages,
            defaultLocale: draft.defaultLanguage,
            onAdd: (language) => notifier.setLanguage(language, selected: true),
            onRemove: (language) =>
                notifier.setLanguage(language, selected: false),
          ),

          const SizedBox(height: AppSpacing.xLarge),

          const SectionTitle('Select default language'),

          RadioGroup<String>(
            groupValue: draft.defaultLanguage,
            onChanged: (value) => notifier.setDefaultLanguage(value!),
            child: Column(
              children: draft.languages
                  .map(
                    (lang) => RadioListTile<String>(
                      title: Text(LanguageCatalog.labelOf(lang)),
                      value: lang,
                    ),
                  )
                  .toList(),
            ),
          ),
        ] else ...[
          OutlinedSurface(
            child: Text(
              'Localization can be added later in your project settings.',
              style: AppTextStyle.secondary(context),
            ),
          ),
        ],
      ],
    );
  }
}
