import 'package:fide/services/dart_translations_parser.dart';
import 'package:fide/services/hand_written_l10n_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartTranslationsParser', () {
    test('reads getters and methods as ARB messages', () {
      final translations = const DartTranslationsParser().parse(r'''
class AppLocalizationsEn extends AppLocalizations {
  @override
  String get cancel => 'Cancel';

  @override
  String deleteMessage(String name, int count) {
    return 'Delete $name (${count})?';
  }

  @override
  String get welcome => 'Welcome '
      'back';
}
''', 'AppLocalizations');

      expect(translations.messages, {
        'cancel': 'Cancel',
        'deleteMessage': 'Delete {name} ({count})?',
        'welcome': 'Welcome back',
      });
      expect(translations.placeholders, {
        'deleteMessage': {'name': 'String', 'count': 'int'},
      });
      expect(translations.unsupported, isEmpty);
    });

    test('flags bodies ARB cannot hold', () {
      final translations = const DartTranslationsParser().parse(r'''
class AppLocalizationsEn extends AppLocalizations {
  @override
  String items(int count) => intl.Intl.plural(count, one: '1 item', other: '$count items');

  @override
  String total(double value) => 'Total ${value.toStringAsFixed(2)}';
}
''', 'AppLocalizations');

      expect(translations.unsupported, ['items', 'total']);
    });
  });

  group('HandWrittenL10nParser', () {
    test('cuts the members fCheck listed out of the generated class', () {
      const content = '''
abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => null;

  /// Picks a locale.
  static Locale pick(List<Locale> locales) => locales.first;

  String get cancel;
}

/// Shorthand.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
''';
      final moved = const HandWrittenL10nParser().extract(
        content,
        'AppLocalizations',
        ['pick', 'extension L10nContext'],
      );

      expect(moved.staticNames, ['pick']);
      expect(moved.extensionMembers, ['l10n']);
      expect(moved.source, '''
/// Picks a locale.
Locale pick(List<Locale> locales) => locales.first;

/// Shorthand.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}''');
    });
  });
}
