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

/// One ARB key: its name, then one row per locale, the template's first,
/// each its badge text before its value. A locale fCheck finds the key
/// [untranslated] in says so, with, given [onTranslate], its Translate
/// button; one lacking a key fCheck leaves out, such as one marked not to
/// be translated, shows the template's text, which the app shows there,
/// with the key's description saying why.
///
/// The one rendering of an ARB key in the localization panel.
class LocalizationEntryWidget extends StatelessWidget {
  /// Creates the entry for [comparison].
  const LocalizationEntryWidget({
    super.key,
    required this.comparison,
    this.templateLocale,
    this.untranslated,
    this.showWarning = false,
    this.onTranslate,
  });

  /// The key and its value per language.
  final ArbComparison comparison;

  /// Called with a locale the key is untranslated in to translate it
  /// there; no Translate buttons when null.
  final ValueChanged<String>? onTranslate;

  /// Whether to flag the key's English value as duplicated.
  final bool showWarning;

  /// The locale of [comparison]'s template value; English, Flutter's
  /// default template, when null.
  final String? templateLocale;

  /// The locales fCheck finds the key untranslated in; null while fCheck
  /// analyzes the project, when the entry judges none.
  final Set<String>? untranslated;
  @override
  Widget build(BuildContext context) {
    final template = templateLocale ?? LanguageCatalog.english;
    final templateValue = comparison.englishValue;
    final others = comparison.otherValues.keys.toList()..sort();

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

            // One row per locale, the template's first
            Column(
              spacing: AppSpacing.medium,
              children: [
                _localeRow(
                  template,
                  templateValue == null
                      ? Text(
                          'Not in the template file',
                          style: AppTextStyle.secondary(context),
                        )
                      : _valueBox(templateValue, AppTextStyle.code),
                ),
                for (final locale in others)
                  _localeRow(locale, _otherValue(context, locale, template)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The row of [locale]: its badge text, then [value].
  static Widget _localeRow(String locale, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.tiny,
      children: [
        Text(LanguageCatalog.badgeOf(locale), style: AppTextStyle.badgeStrong),
        Expanded(child: value),
      ],
    );
  }

  /// What the row of [locale], another than the [template]'s, shows: its
  /// value; what fCheck finds wrong with it and its Translate button; or,
  /// where the key is missing as intended, the template's text the app
  /// shows instead, dimmed, and why.
  Widget _otherValue(BuildContext context, String locale, String template) {
    final value = comparison.otherValues[locale];
    final untranslated = this.untranslated;
    final templateValue = comparison.englishValue;
    final secondary = AppTextStyle.secondary(context);

    if (untranslated != null && untranslated.contains(locale)) {
      final translate = onTranslate;
      return _valueColumn([
        if (value != null) _valueBox(value, AppTextStyle.code),
        Wrap(
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.tiny,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              value == null ? 'Missing' : 'Needs translation',
              style: AppTextStyle.caption.copyWith(
                color: StatusTone.error.readableIn(
                  Theme.of(context).colorScheme,
                ),
              ),
            ),
            if (translate != null)
              // One key of Translate with AI
              PrimaryButton(
                icon: QuickFix.translateKeys.icon,
                // Its row's badge names the language
                label: 'Translate',
                onPressed: templateValue == null
                    ? null
                    : () => translate(locale),
              ),
          ],
        ),
      ]);
    }
    if (value != null) return _valueBox(value, AppTextStyle.code);
    // Missing: fCheck still analyzing, nothing to judge yet
    if (untranslated == null) {
      return Text('Not in this locale\'s file', style: secondary);
    }
    // Missing as intended: the app shows the template's text
    final description = comparison.description;
    return _valueColumn([
      if (templateValue != null)
        _valueBox(
          templateValue,
          AppTextStyle.code.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      Text(
        'Intentionally the same as ${LanguageCatalog.nameOf(template)}'
        '${description == null ? '' : ': $description'}',
        style: secondary,
      ),
    ]);
  }

  /// [text] in a box, in [style].
  static Widget _valueBox(String text, TextStyle style) {
    return OutlinedSurface(
      padding: SurfacePadding.dense,
      child: Text(
        text,
        softWrap: true,
        maxLines: AppMetric.translationPreviewLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  /// [children] stacked in a locale's row, as wide as its value boxes.
  static Widget _valueColumn(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.tiny,
    children: children,
  );
}
