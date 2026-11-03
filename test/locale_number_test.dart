import 'package:fide/models/locale_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps every digit and only adds locale separators', () {
    final text = 1234456.localized;

    expect(text.replaceAll(RegExp(r'\D'), ''), '1234456');
    expect(text.length, greaterThan('1234456'.length));
    expect(7.localized, '7');
  });

  test('count is singular only for one', () {
    expect(1.count('issue'), '1 issue');
    expect(0.count('issue'), '0 issues');
    expect(2.count('file'), '2 files');
  });

  test('NumberLocale formats with the locale separators', () {
    expect(NumberLocale('de').format(1234.5), '1.234,5');
    expect(NumberLocale('xx_unknown').format(1234.5), '1,234.5');
    expect(NumberLocale.fallback.format(1234.567), '1,234.57');
  });

  test('the locale set once from main formats every number', () {
    addTearDown(() => LocaleNumber.locale = NumberLocale.fallback);

    LocaleNumber.locale = NumberLocale('de');

    expect(1234.5.localized, '1.234,5');
    expect(1204.count('issue'), '1.204 issues');
  });
}
