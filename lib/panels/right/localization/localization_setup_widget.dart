import 'package:fide/constants/constants.dart';
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
          Text(
            'Setup Localization',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Your Flutter project needs localization setup.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxLarge),

          // One-click setup card
          /// Handles `_buildActionCard`.
          _buildActionCard(
            context,
            '🚀 Initialize Localization',
            'Automatically configure everything needed for localization',
            [
              '• Add flutter_localizations & intl packages',
              '• Create l10n directory and ARB files',
              '• Generate AppLocalizations class',
            ],
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Initialize'),
              onPressed: onInitializeLocalization,
            ),
          ),

          // Show Update main.dart card conditionally
          if (showUpdateMainDart) ...[
            const SizedBox(height: AppSpacing.xLarge),

            // Main.dart update card
            _buildActionCard(
              context,
              '🔧 Update main.dart',
              'Configure your app to use AppLocalizations',
              [
                '• Wrap app with MaterialApp.router',
                '• Add localizations delegates',
                '• Set supported locales',
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Update main.dart'),
                onPressed: onUpdateMainDart,
              ),
            ),
          ],

          // Simple next steps
          const SizedBox(height: AppSpacing.xxLarge),
          Text(
            'Next Steps',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'After setup, use AppLocalizations.of(context) to display localized strings in your widgets.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Handles `_buildActionCard`.
  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    List<String> steps,
    Widget button,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppIconSize.large),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.large),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outline.withValues(alpha: AppOpacity.selected),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xLarge),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.tiny),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      step,
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppIconSize.large),
          button,
        ],
      ),
    );
  }
}
