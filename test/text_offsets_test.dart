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
}
