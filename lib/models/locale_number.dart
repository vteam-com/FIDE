import 'package:intl/intl.dart';

/// Formats numbers with the grouping and decimal separators of the user's
/// system locale (1,234,567.5 in the US, 1.234.567,5 in Germany), with at
/// most two decimals.
extension LocaleNumber on num {
  /// Locale used until [useLocale] is called, and when intl lacks one.
  static const String _fallbackLocale = 'en';

  /// Most decimals shown, like fCheck's CLI (`-9.01%`).
  static const int _maxFractionDigits = 2;

  /// Formatter for the locale [useLocale] set.
  static NumberFormat _format = _formatFor(_fallbackLocale);

  /// Formats numbers with the separators of [localeName], such as the
  /// host's `en_US`; the default locale when intl lacks it.
  static void useLocale(String localeName) {
    final locale =
        Intl.verifiedLocale(
          localeName,
          NumberFormat.localeExists,
          onFailure: (_) => Intl.defaultLocale ?? _fallbackLocale,
        ) ??
        _fallbackLocale;
    _format = _formatFor(locale);
  }

  /// A formatter for [locale] with at most [_maxFractionDigits] decimals.
  static NumberFormat _formatFor(String locale) =>
      NumberFormat.decimalPattern(locale)
        ..maximumFractionDigits = _maxFractionDigits;

  /// This number with the user's locale separators.
  String get localized => _format.format(this);

  /// This number [localized], then [noun], plural unless the number is
  /// one: `1 issue`, `1,204 issues`.
  String count(String noun) => '$localized $noun${this == 1 ? '' : 's'}';
}
