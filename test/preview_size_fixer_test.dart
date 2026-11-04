import 'dart:ui';

import 'package:fide/services/preview_size_fixer.dart';
import 'package:flutter_test/flutter_test.dart';

String? _fix(String content, {int annotation = 0}) =>
    const PreviewSizeFixer().withSize(
      content,
      label: 'cardPreview',
      annotation: annotation,
      size: const Size(359.5, 48),
    );

void main() {
  test('writes the size, rounded up, into empty arguments', () {
    expect(
      _fix('@Preview()\nWidget cardPreview() => const Card();\n'),
      '@Preview(size: Size(360, 48))\nWidget cardPreview() => const Card();\n',
    );
  });

  test('appends the size after the other arguments', () {
    expect(
      _fix("@Preview(name: 'Card')\nWidget cardPreview() => x;"),
      "@Preview(name: 'Card', size: Size(360, 48))\nWidget cardPreview() => x;",
    );
    expect(
      _fix("@Preview(\n  name: 'Card',\n)\nWidget cardPreview() => x;"),
      "@Preview(\n  name: 'Card', size: Size(360, 48),\n)\n"
      'Widget cardPreview() => x;',
    );
  });

  test('replaces a size already there', () {
    expect(
      _fix('@Preview(size: Size.fromWidth(200))\nWidget cardPreview() => x;'),
      '@Preview(size: Size(360, 48))\nWidget cardPreview() => x;',
    );
  });

  test('edits the annotation at the given position', () {
    expect(
      _fix(
        "@Preview(name: 'A')\n@Preview(name: 'B')\nWidget cardPreview() => x;",
        annotation: 1,
      ),
      "@Preview(name: 'A')\n@Preview(name: 'B', size: Size(360, 48))\n"
      'Widget cardPreview() => x;',
    );
  });

  test('leaves alone what is not a plain Preview', () {
    expect(_fix('@BrightnessPreview()\nWidget cardPreview() => x;'), isNull);
    expect(_fix('@Preview.named()\nWidget cardPreview() => x;'), isNull);
    expect(_fix('@Preview()\nWidget other() => x;'), isNull);
  });
}
