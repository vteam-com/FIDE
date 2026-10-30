import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter/material.dart';

/// Represents `LocalizationSetupWidget`.
class LocalizationSetupWidget extends StatelessWidget {
  const LocalizationSetupWidget({
    super.key,
    required this.onInitializeLocalization,
    required this.onUpdateMainDart,
    this.isInitializing = false,
    this.showUpdateMainDart = true, // Show by default, but can be hidden
  });

  final bool isInitializing;

  final VoidCallback onInitializeLocalization;

  final VoidCallback onUpdateMainDart;

  final bool showUpdateMainDart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Setup Localization'),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Your Flutter project needs localization setup.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxLarge),

          // One-click setup card
          ActionCard(
            title: '🚀 Initialize Localization',
            description:
                'Automatically configure everything needed for localization',
            steps: const [
              'Add flutter_localizations & intl packages',
              'Create l10n directory and ARB files',
              'Generate AppLocalizations class',
            ],
            action: ElevatedButton.icon(
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Initialize'),
              onPressed: onInitializeLocalization,
            ),
          ),

          // Show Update main.dart card conditionally
          if (showUpdateMainDart) ...[
            const SizedBox(height: AppSpacing.xLarge),

            // Main.dart update card
            ActionCard(
              title: '🔧 Update main.dart',
              description: 'Configure your app to use AppLocalizations',
              steps: const [
                'Wrap app with MaterialApp.router',
                'Add localizations delegates',
                'Set supported locales',
              ],
              action: ElevatedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Update main.dart'),
                onPressed: onUpdateMainDart,
              ),
            ),
          ],

          // Simple next steps
          const SizedBox(height: AppSpacing.xxLarge),
          const SectionTitle('Next Steps'),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'After setup, use AppLocalizations.of(context) to display localized strings in your widgets.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
