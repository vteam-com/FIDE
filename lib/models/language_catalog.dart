/// The languages FIDE offers to localize an app into, and how it names any
/// locale: on its badge, in a menu and to the model translating into it.
class LanguageCatalog {
  const LanguageCatalog._();

  /// Separates a locale's language from its script or region, as in
  /// `pt_BR`.
  static const String _subtagSeparator = '_';

  /// The languages offered, by language code, in the alphabetical order of
  /// their names: each one `flutter_localizations` translates its own
  /// widgets into.
  static const Map<String, String> names = {
    'af': 'Afrikaans',
    'ar': 'Arabic',
    'bn': 'Bengali',
    'bg': 'Bulgarian',
    'ca': 'Catalan',
    'zh': 'Chinese',
    'hr': 'Croatian',
    'cs': 'Czech',
    'da': 'Danish',
    'nl': 'Dutch',
    'en': 'English',
    'et': 'Estonian',
    'fil': 'Filipino',
    'fi': 'Finnish',
    'fr': 'French',
    'de': 'German',
    'el': 'Greek',
    'he': 'Hebrew',
    'hi': 'Hindi',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'lv': 'Latvian',
    'lt': 'Lithuanian',
    'ms': 'Malay',
    'nb': 'Norwegian Bokmål',
    'fa': 'Persian',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sr': 'Serbian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'es': 'Spanish',
    'sw': 'Swahili',
    'sv': 'Swedish',
    'ta': 'Tamil',
    'th': 'Thai',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'ur': 'Urdu',
    'vi': 'Vietnamese',
  };

  /// [locale] on its badge, such as `FR` or `PT_BR`.
  static String badgeOf(String locale) => locale.toUpperCase();

  /// [locale] in a menu or a list, such as `French (FR)`.
  static String labelOf(String locale) =>
      '${names[languageOf(locale)] ?? locale} (${badgeOf(locale)})';

  /// The language of [locale], such as `pt` for `pt_BR`.
  static String languageOf(String locale) =>
      locale.split(_subtagSeparator).first;

  /// [locale] as the model is told to translate into it: its language's
  /// name, such as `French`, followed by the locale when it names a script
  /// or a region, such as `Portuguese (pt_BR)`; the locale itself for a
  /// language not in [names].
  static String nameOf(String locale) {
    final name = names[languageOf(locale)];
    if (name == null) return locale;
    return locale.contains(_subtagSeparator) ? '$name ($locale)' : name;
  }
}
