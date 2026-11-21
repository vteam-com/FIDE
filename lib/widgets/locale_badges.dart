import 'package:fide/constants/constants.dart';
import 'package:fide/models/language_catalog.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/dropdown_menu_button.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:material_ui/material_ui.dart';

/// An app's locales as badges, such as `EN` `FR`, each named by its
/// tooltip. Given [onRemove], every locale but [defaultLocale] has a button
/// removing it; given [onAdd], a menu after them adds one of the
/// [LanguageCatalog] languages not shown yet.
///
/// The one rendering of an app's locales: the project overview's
/// Localization card, the Localization panel and the new project wizard.
class LocaleBadges extends StatelessWidget {
  /// Creates the badges of [locales].
  const LocaleBadges({
    super.key,
    required this.locales,
    this.defaultLocale,
    this.onAdd,
    this.onRemove,
  });

  /// Label of the menu adding a locale.
  static const String addLabel = 'Add locale';

  /// The locale the app falls back to, which can't be removed, such as the
  /// template ARB file's; none when null.
  final String? defaultLocale;

  /// The locales shown, in order.
  final Iterable<String> locales;

  /// Called with the language picked in the menu adding one; no menu when
  /// null.
  final ValueChanged<String>? onAdd;

  /// Called with the locale whose remove button is pressed; no buttons
  /// when null.
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final onAdd = this.onAdd;
    final missing = [
      for (final language in LanguageCatalog.names.keys)
        if (!locales.contains(language)) language,
    ];
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.medium,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final locale in locales) _badge(locale),
        if (onAdd != null && missing.isNotEmpty)
          DropdownMenuButton<String>(
            tooltip: addLabel,
            itemBuilder: (_ /*context*/) => [
              for (final language in missing)
                IconMenuItem(
                  value: language,
                  icon: null,
                  label: LanguageCatalog.labelOf(language),
                ),
            ],
            onSelected: onAdd,
            label: Text(addLabel, style: AppTextStyle.caption),
          ),
      ],
    );
  }

  /// The badge of [locale], followed by its remove button when it has one.
  Widget _badge(String locale) {
    final label = LanguageCatalog.labelOf(locale);
    final isDefault = locale == defaultLocale;
    final badge = Tooltip(
      message: isDefault ? '$label, the default' : label,
      child: BadgeStatus.info(
        text: LanguageCatalog.badgeOf(locale),
        large: true,
      ),
    );
    final onRemove = this.onRemove;
    if (onRemove == null || isDefault) return badge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        CompactIconButton(
          icon: Icons.close,
          tooltip: 'Remove ${LanguageCatalog.nameOf(locale)}',
          onPressed: () => onRemove(locale),
        ),
      ],
    );
  }
}
