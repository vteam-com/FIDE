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

  test('useLocale switches to the locale separators', () {
    addTearDown(() => LocaleNumber.useLocale('en'));

    LocaleNumber.useLocale('de');
    expect(1234.5.localized, '1.234,5');

    LocaleNumber.useLocale('xx_unknown');
    expect(1234.5.localized, '1,234.5');
  });
}
