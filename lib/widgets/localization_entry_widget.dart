// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/widgets/badge_status.dart';

class LocalizationEntryWidget extends StatelessWidget {
  final ArbComparison comparison;
  final bool showWarning;

  const LocalizationEntryWidget({
    super.key,
    required this.comparison,
    this.showWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    // Collect all available translations
    final translations = <String, String>{};

    // Add English if available
    if (comparison.englishValue != null) {
      translations['EN'] = comparison.englishValue!;
    }

    // Add other languages that have this key
    for (final entry in comparison.otherValues.entries) {
      if (entry.value != null) {
        translations[entry.key.toUpperCase()] = entry.value!;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            // Key at the top with optional warning badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    comparison.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                if (showWarning) ...[
                  const SizedBox(width: 8),
                  BadgeStatus.warning(text: 'D', fontSize: 9),
                ],
              ],
            ),

            // Translations
            Column(
              spacing: 8,
              children: translations.entries.map((entry) {
                return _buildLocString(context, entry.key, entry.value);
              }).toList(),
            ),

            // Show missing languages if any
            if (comparison.missingInLanguages.isNotEmpty ||
                comparison.isMissingInEnglish) ...[
              const SizedBox(height: 12),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Missing in: ${comparison.isMissingInEnglish ? 'EN, ' : ''}${comparison.missingInLanguages.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocString(
    BuildContext context,
    String languageCode,
    String translation,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        // Language label
        Text(
          languageCode,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        // Translation value
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              translation,
              softWrap: true,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontFamilyFallback: ['Courier', 'Courier New'],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
