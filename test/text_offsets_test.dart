import 'package:fide/models/text_offsets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = 'ab\ncde\n\nf';

  test('positionOf counts lines and columns from 1', () {
    expect(TextOffsets.positionOf(text, 0), (line: 1, column: 1));
    expect(TextOffsets.positionOf(text, 4), (line: 2, column: 2));
    expect(TextOffsets.positionOf(text, 7), (line: 3, column: 1));
    expect(TextOffsets.positionOf(text, 99), (line: 4, column: 2));
  });

  test('offsetOf inverts positionOf and clamps the column', () {
    expect(TextOffsets.offsetOf(text, 2, column: 2), 4);
    expect(TextOffsets.offsetOf(text, 2, column: 99), 6);
    expect(TextOffsets.offsetOf(text, 5), isNull);
    expect(TextOffsets.offsetOf(text, 0), isNull);
  });

  test('applyEdits replaces from the end so offsets stay valid', () {
    expect(
      TextOffsets.applyEdits('const a = 1;', {
        0: (6, ''),
        6: (1, 'b'),
        12: (0, '!'),
      }),
      'b = 1;!',
    );
  });

  /// [text] with [edits] applied one by one from the end, as applyEdits
  /// did before it rebuilt the text in one pass.
  String applyOneByOne(String text, Map<int, (int, String)> edits) {
    var result = text;
    for (final offset in edits.keys.toList()..sort((a, b) => b - a)) {
      final (length, replacement) = edits[offset]!;
      result = result.replaceRange(offset, offset + length, replacement);
    }
    return result;
  }

  /// The position of [offset] in [text] by counting the newlines before
  /// it, as positionOf did before it stopped copying the text.
  ({int line, int column}) positionByCopy(String text, int offset) {
    final end = offset.clamp(0, text.length);
    final before = text.substring(0, end);
    return (
      line: '\n'.allMatches(before).length + 1,
      column: end - before.lastIndexOf('\n'),
    );
  }

  test('positionOf gives the same positions at every offset', () {
    for (final sample in ['', 'a', '\n', '\n\n', text, 'x\r\ny\n', 'é😀\nz']) {
      for (var offset = -1; offset <= sample.length + 1; offset++) {
        expect(
          TextOffsets.positionOf(sample, offset),
          positionByCopy(sample, offset),
          reason: 'offset $offset of ${sample.codeUnits}',
        );
      }
    }
  });

  test('applyEdits gives the same text as edits one by one', () {
    const source = 'class A {\n  final int a = 1;\n}\n';
    final samples = <Map<int, (int, String)>>[
      {},
      {0: (0, '// x\n')},
      {source.length: (0, '// end\n')},
      {0: (5, 'mixin'), 18: (1, 'b'), 26: (1, '2')},
      // Adjacent edits and an empty replacement
      {6: (1, 'B'), 7: (2, ''), 9: (0, '{ ')},
      {0: (source.length, 'all')},
    ];
    for (final edits in samples) {
      expect(
        TextOffsets.applyEdits(source, edits),
        applyOneByOne(source, edits),
        reason: '$edits',
      );
    }
  });

  test('applyEdits applies overlapping edits one by one from the end', () {
    final edits = {0: (4, 'x'), 2: (3, 'yz')};

    expect(
      TextOffsets.applyEdits('abcdefg', edits),
      applyOneByOne('abcdefg', edits),
    );
  });

  test('applyEdits throws on an edit outside the text', () {
    expect(() => TextOffsets.applyEdits('abc', {2: (5, '')}), throwsRangeError);
    expect(
      () => TextOffsets.applyEdits('abc', {-1: (1, '')}),
      throwsRangeError,
    );
  });
}
