import 'package:fide/models/dart_string_literal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quote escapes what a single-quoted literal cannot hold', () {
    expect(
      DartStringLiteral.quote('It\'s \$5\\day\nnow\r'),
      r"'It\'s \$5\\day\nnow\r'",
    );
  });

  test('valueOf reads back what quote wrote', () {
    const value = 'It\'s \$5\\day\nnow\r';
    final quoted = DartStringLiteral.quote(value);

    expect(
      DartStringLiteral.valueOf(quoted.substring(1, quoted.length - 1)),
      value,
    );
  });
}
