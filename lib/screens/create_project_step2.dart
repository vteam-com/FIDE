import 'package:fide/constants/constants.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/step_header.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wizard's second step: whether to localize, which languages and the
/// default one, kept in [createProjectDraftProvider].
class CreateProjectStep2 extends ConsumerWidget {
  /// Creates the step.
  const CreateProjectStep2({super.key});

  /// This step's place in the wizard.
  static const int _stepNumber = 2;

  /// Languages offered, by code.
  static const Map<String, String> _languages = {
    'en': 'English (EN)',
    'fr': 'French (FR)',
    'es': 'Spanish (ES)',
    'de': 'German (DE)',
    'it': 'Italian (IT)',
    'pt': 'Portuguese (PT)',
    'ja': 'Japanese (JA)',
    'ko': 'Korean (KO)',
    'zh': 'Chinese (ZH)',
    'ar': 'Arabic (AR)',
    'hi': 'Hindi (HI)',
    'ru': 'Russian (RU)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(createProjectDraftProvider);
    final notifier = ref.read(createProjectDraftProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppIconSize.xLarge,
      children: [
        StepHeader(number: _stepNumber, title: 'Localization Settings'),

        const SizedBox(height: AppSpacing.xLarge),

        // Project summary
        SurfaceCard(
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

          Column(
            children: _languages.entries
                .map(
                  (entry) => CheckboxListTile(
                    title: Text(entry.value),
                    value: draft.languages.contains(entry.key),
                    onChanged: (bool? value) => notifier.setLanguage(
                      entry.key,
                      selected: value == true,
                    ),
                  ),
                )
                .toList(),
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
                      title: Text(_languages[lang]!),
                      value: lang,
                    ),
                  )
                  .toList(),
            ),
          ),
        ] else ...[
          SurfaceCard(
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
