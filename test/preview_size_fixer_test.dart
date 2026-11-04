import 'package:fide/services/preview_size_fixer.dart';
import 'package:flutter_test/flutter_test.dart';

String? _fix(
  String content, {
  int annotation = 0,
  double? width = 359.5,
  double? height = 48,
}) => const PreviewSizeFixer().withSize(
  content,
  label: 'cardPreview',
  annotation: annotation,
  width: width,
  height: height,
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

  test('leaves the Auto width or height out', () {
    expect(
      _fix('@Preview()\nWidget cardPreview() => x;', width: null),
      '@Preview(size: Size.fromHeight(48))\nWidget cardPreview() => x;',
    );
    expect(
      _fix('@Preview()\nWidget cardPreview() => x;', height: null),
      '@Preview(size: Size.fromWidth(360))\nWidget cardPreview() => x;',
    );
  });

  test('removes the size when both are Auto', () {
    String? auto(String content) => _fix(content, width: null, height: null);
    expect(
      auto("@Preview(name: 'A', size: Size(1, 2))\nWidget cardPreview() => x;"),
      "@Preview(name: 'A')\nWidget cardPreview() => x;",
    );
    expect(
      auto("@Preview(size: Size(1, 2), name: 'A')\nWidget cardPreview() => x;"),
      "@Preview(name: 'A')\nWidget cardPreview() => x;",
    );
    expect(auto('@Preview()\nWidget cardPreview() => x;'), isNull);
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
