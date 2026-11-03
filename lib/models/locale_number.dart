import 'package:intl/intl.dart';

/// The locale numbers are shown in: its grouping and decimal separators
/// (1,234,567.5 in the US, 1.234.567,5 in Germany), with at most two
/// decimals.
class NumberLocale {
  /// Locale used when intl lacks the requested one, and until `main`
  /// sets the host's.
  static const String _fallbackLocale = 'en';

  /// Most decimals shown, like fCheck's CLI (`-9.01%`).
  static const int _maxFractionDigits = 2;

  /// English separators.
  static final NumberLocale fallback = NumberLocale(_fallbackLocale);

  final NumberFormat _format;

  /// Formats with the separators of [localeName], such as the host's
  /// `en_US`; the default locale when intl lacks it.
  NumberLocale(String localeName)
    : _format = NumberFormat.decimalPattern(
        Intl.verifiedLocale(
              localeName,
              NumberFormat.localeExists,
              onFailure: (_) => Intl.defaultLocale ?? _fallbackLocale,
            ) ??
            _fallbackLocale,
      )..maximumFractionDigits = _maxFractionDigits;

  /// [value] with this locale's separators.
  String format(num value) => _format.format(value);
}

/// Formats numbers with the [NumberLocale] of the user's system, which
/// `main` sets once in [locale].
extension LocaleNumber on num {
  /// The locale numbers are shown in, set once by `main` from the host;
  /// [NumberLocale.fallback] until then.
  static NumberLocale locale = NumberLocale.fallback;

  /// This number with the user's locale separators.
  String get localized => locale.format(this);

  /// This number [localized], then [noun], plural unless the number is
  /// one: `1 issue`, `1,204 issues`.
  String count(String noun) => '$localized $noun${this == 1 ? '' : 's'}';
}
