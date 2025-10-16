import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Setup Localization',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your Flutter project needs localization setup.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // One-click setup card
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
            const SizedBox(height: 16),

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
          const SizedBox(height: 24),
          Text(
            'Next Steps',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'After setup, use AppLocalizations.of(context) to display localized strings in your widgets.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    List<String> steps,
    Widget button,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
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
          const SizedBox(height: 20),
          button,
        ],
      ),
    );
  }
}
