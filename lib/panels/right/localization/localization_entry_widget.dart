// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/language_catalog.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/quick_fix_icon.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:material_ui/material_ui.dart';

/// One ARB key: its name, its value in every locale that has it, the
/// template's first, the locales missing it and, given [onTranslate], a
/// Translate button per missing locale; each locale written as its badge
/// is.
///
/// The one rendering of an ARB key in the localization panel.
class LocalizationEntryWidget extends StatelessWidget {
  /// Creates the entry for [comparison].
  const LocalizationEntryWidget({
    super.key,
    required this.comparison,
    this.templateLocale,
    this.showWarning = false,
    this.onTranslate,
  });

  /// The key and its value per language.
  final ArbComparison comparison;

  /// Called with a language the key is missing in to translate it there;
  /// no Translate buttons when null.
  final ValueChanged<String>? onTranslate;

  /// Whether to flag the key's English value as duplicated.
  final bool showWarning;

  /// The locale of [comparison]'s template value; English, Flutter's
  /// default template, when null.
  final String? templateLocale;

  @override
  Widget build(BuildContext context) {
    final template = templateLocale ?? LanguageCatalog.english;
    // Every value by locale, the template's first
    final translations = <String, String>{
      template: ?comparison.englishValue,
      for (final MapEntry(:key, :value) in comparison.otherValues.entries)
        key: ?value,
    };
    final missing = [
      if (comparison.isMissingInEnglish) template,
      ...comparison.missingInLanguages,
    ];

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
              children: [
                for (final MapEntry(:key, :value) in translations.entries)
                  _buildLocString(key, value),
              ],
            ),

            // Show missing locales if any
            if (missing.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.medium),
                child: Text(
                  'Missing in: '
                  '${missing.map(LanguageCatalog.badgeOf).join(', ')}',
                  style: AppTextStyle.caption.copyWith(
                    color: StatusTone.error.readableIn(
                      Theme.of(context).colorScheme,
                    ),
                  ),
                ),
              ),
              if (onTranslate case final translate?)
                Wrap(
                  spacing: AppSpacing.medium,
                  runSpacing: AppSpacing.tiny,
                  children: [
                    for (final language in comparison.missingInLanguages)
                      // One key of Translate with AI
                      PrimaryButton(
                        icon: QuickFix.translateKeys.icon,
                        label:
                            'Translate to ${LanguageCatalog.nameOf(language)}',
                        onPressed: comparison.englishValue == null
                            ? null
                            : () => translate(language),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// The [translation] of [locale], after its badge text.
  Widget _buildLocString(String locale, String translation) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.tiny,
      children: [
        Text(LanguageCatalog.badgeOf(locale), style: AppTextStyle.badgeStrong),
        // Translation value
        Expanded(
          child: OutlinedSurface(
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
