import 'dart:io';

import 'package:intl/intl.dart';

/// Formats numbers with the grouping and decimal separators of the user's
/// system locale (1,234,567.5 in the US, 1.234.567,5 in Germany), with at
/// most two decimals.
extension LocaleNumber on num {
  /// The user's system locale, or the default one when intl lacks it.
  static final String _locale =
      Intl.verifiedLocale(
        Platform.localeName,
        NumberFormat.localeExists,
        onFailure: (_) => Intl.defaultLocale ?? 'en',
      ) ??
      'en';

  /// Most decimals shown, like fCheck's CLI (`-9.01%`).
  static const int _maxFractionDigits = 2;

  /// Formatter for [_locale].
  static final NumberFormat _format = NumberFormat.decimalPattern(_locale)
    ..maximumFractionDigits = _maxFractionDigits;

  /// This number with the user's locale separators.
  String get localized => _format.format(this);
}
