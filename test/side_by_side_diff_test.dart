import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SideBySideDiff.computeLines', () {
    test('changed version numbers show as whole-line edits', () {
      const oldText = 'dependencies:\n  cloud_firestore: ^6.2.0\n\n  intl: any';
      const newText = 'dependencies:\n  cloud_firestore: ^7.1.0\n\n  intl: any';

      final lines = SideBySideDiff.computeLines(oldText, newText);

      expect(lines.map((l) => l.type).toList(), [
        DiffType.equal,
        DiffType.deletion,
        DiffType.addition,
        DiffType.equal,
        DiffType.equal,
      ]);
      expect(lines[1].oldContent, '  cloud_firestore: ^6.2.0');
      expect(lines[2].newContent, '  cloud_firestore: ^7.1.0');
      expect(lines[3].oldLine, '3');
      expect(lines[3].newLine, '3');
      expect(lines[4].newContent, '  intl: any');
    });

    test('new file shows every line as an addition', () {
      final lines = SideBySideDiff.computeLines('', 'a\nb');

      expect(lines.every((l) => l.type == DiffType.addition), isTrue);
      expect(lines.map((l) => l.newLine).toList(), ['1', '2']);
    });
  });
}
