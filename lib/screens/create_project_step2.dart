import 'package:flutter/material.dart';

class CreateProjectStep2 extends StatelessWidget {
  final String? projectName;
  final String projectLocation;
  final bool wantsLocalization;
  final Set<String> selectedLanguages;
  final String defaultLanguage;
  final void Function(bool) onWantsLocalizationChanged;
  final void Function(String, bool) onLanguageSelectionChanged;
  final void Function(String) onDefaultLanguageChanged;
  final void Function(bool canProceed) onValidationChanged;

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
      spacing: 24,
      children: [
        // Step indicator
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Center(
                child: Text(
                  '2',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Localization Settings'),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 2,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Project summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                'Project: $projectName',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Location: $projectLocation',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Do you want to localize your app?',
          style: Theme.of(context).textTheme.titleMedium,
        ),

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
          const SizedBox(height: 16),

          Text(
            'Select languages to support:',
            style: Theme.of(context).textTheme.titleSmall,
          ),

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

          const SizedBox(height: 16),

          Text(
            'Select default language:',
            style: Theme.of(context).textTheme.titleSmall,
          ),

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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
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
