import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/step_header.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:flutter/material.dart';

/// Represents `CreateProjectStep2`.
class CreateProjectStep2 extends StatelessWidget {
  const CreateProjectStep2({
    super.key,
    required this.projectName,
    required this.projectLocation,
    required this.wantsLocalization,
    required this.selectedLanguages,
    required this.defaultLanguage,
    required this.onWantsLocalizationChanged,
    required this.onLanguageSelectionChanged,
    required this.onDefaultLanguageChanged,
    required this.onValidationChanged,
  });

  /// This step's place in the wizard.
  static const int _stepNumber = 2;

  final String defaultLanguage;

  final void Function(String) onDefaultLanguageChanged;

  final void Function(String, bool) onLanguageSelectionChanged;

  final void Function(bool canProceed) onValidationChanged;

  final void Function(bool) onWantsLocalizationChanged;

  final String projectLocation;

  final String? projectName;

  final Set<String> selectedLanguages;

  final bool wantsLocalization;

  @override
  Widget build(BuildContext context) {
    final languages = {
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
              SectionTitle('Project: $projectName'),
              Text(
                'Location: $projectLocation',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xLarge),

        const SectionTitle('Do you want to localize your app?'),

        RadioGroup<bool>(
          groupValue: wantsLocalization,
          onChanged: (value) => onWantsLocalizationChanged(value!),
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

        if (wantsLocalization) ...[
          const SizedBox(height: AppSpacing.xLarge),

          const SectionTitle('Select languages to support'),

          Column(
            children: languages.entries
                .map(
                  (entry) => CheckboxListTile(
                    title: Text(entry.value),
                    value: selectedLanguages.contains(entry.key),
                    onChanged: (bool? value) {
                      onLanguageSelectionChanged(entry.key, value == true);
                    },
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: AppSpacing.xLarge),

          const SectionTitle('Select default language'),

          RadioGroup<String>(
            groupValue: defaultLanguage,
            onChanged: (value) => onDefaultLanguageChanged(value!),
            child: Column(
              children: selectedLanguages
                  .map(
                    (lang) => RadioListTile<String>(
                      title: Text(languages[lang]!),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
