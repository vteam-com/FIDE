// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

/// Represents `LocalizationEntryWidget`.
class LocalizationEntryWidget extends StatelessWidget {
  const LocalizationEntryWidget({
    super.key,
    required this.comparison,
    this.showWarning = false,
  });

  final ArbComparison comparison;

  final bool showWarning;

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
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tiny,
        vertical: AppSpacing.micro,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.tiny),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.tiny,
          children: [
            // Key at the top with optional warning badge
            Row(
              children: [
                Expanded(
                  child: Text(comparison.key, style: AppTextStyle.title),
                ),
                if (showWarning) ...[
                  const SizedBox(width: AppSpacing.medium),
                  BadgeStatus.warning(text: 'D'),
                ],
              ],
            ),

            // Translations
            Column(
              spacing: AppSpacing.medium,
              children: translations.entries.map((entry) {
                /// Handles `_buildLocString`.
                return _buildLocString(entry.key, entry.value);
              }).toList(),
            ),

            // Show missing languages if any
            if (comparison.missingInLanguages.isNotEmpty ||
                comparison.isMissingInEnglish) ...[
              const SizedBox(height: AppSpacing.large),
              const SizedBox(height: AppSpacing.large),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.medium),
                child: Text(
                  'Missing in: ${comparison.isMissingInEnglish ? 'EN, ' : ''}${comparison.missingInLanguages.join(', ')}',
                  style: AppTextStyle.caption.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handles `_buildLocString`.
  Widget _buildLocString(String languageCode, String translation) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.tiny,
      children: [
        // Language label
        Text(languageCode, style: AppTextStyle.badgeStrong),
        // Translation value
        Expanded(
          child: SurfaceCard(
            padding: SurfacePadding.dense,
            child: Text(
              translation,
              softWrap: true,
              maxLines: AppMetric.translationPreviewLines,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.code,
            ),
          ),
        ),
      ],
    );
  }
}
