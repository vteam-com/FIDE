import 'package:flutter/material.dart';

class LocalizationSetupWidget extends StatelessWidget {
  final VoidCallback onInitializeLocalization;
  final VoidCallback onUpdateMainDart;
  final bool isInitializing;

  const LocalizationSetupWidget({
    super.key,
    required this.onInitializeLocalization,
    required this.onUpdateMainDart,
    this.isInitializing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Localization Not Set Up',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your Flutter project doesn\'t have localization configured yet. Here\'s what you need to know:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Quick Setup Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚀 Quick Setup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Click the button below to automatically set up localization for your project:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Initialize Localization'),
                    onPressed: onInitializeLocalization,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What it does section
          Text(
            'What "Initialize Localization" will do:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildStepItem(
            context,
            'Add flutter_localizations and intl packages to pubspec.yaml',
          ),
          _buildStepItem(context, 'Configure l10n settings in pubspec.yaml'),
          _buildStepItem(context, 'Create lib/l10n/ directory'),
          _buildStepItem(
            context,
            'Generate template ARB files (English + French)',
          ),
          _buildStepItem(
            context,
            'Run flutter gen-l10n to create AppLocalizations class',
          ),

          const SizedBox(height: 24),

          // Manual steps
          Text(
            'After initialization, you\'ll need to manually:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildManualStep(context, 'Update main.dart to use AppLocalizations'),
          _buildManualStep(
            context,
            'Use AppLocalizations.of(context) in your widgets',
          ),

          const SizedBox(height: 24),

          // Quick main.dart update
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔧 Quick Main.dart Update',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Automatically update your main.dart to use AppLocalizations:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.code),
                    label: const Text('Update main.dart'),
                    onPressed: onUpdateMainDart,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Resources
          Text(
            '📚 Resources',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '• Flutter Internationalization: https://flutter.dev/docs/development/accessibility-and-localization/internationalization',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '• ARB File Format: https://github.com/google/app-resource-bundle',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildManualStep(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.edit,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
