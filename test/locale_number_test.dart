import 'package:fide/models/locale_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps every digit and only adds locale separators', () {
    final text = 1234456.localized;

    expect(text.replaceAll(RegExp(r'\D'), ''), '1234456');
    expect(text.length, greaterThan('1234456'.length));
    expect(7.localized, '7');
  });
}
