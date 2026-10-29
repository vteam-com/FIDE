import 'package:fide/models/editor_search.dart';
import 'package:fide/providers/code_formatter.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorSearch', () {
    test('finds case-insensitive and whole-word matches', () {
      const text = 'Foo foo food barfoo';

      expect(EditorSearch.findMatches(text, 'foo'), [0, 4, 8, 16]);
      expect(EditorSearch.findMatches(text, 'foo', caseSensitive: true), [
        4,
        8,
        16,
      ]);
      expect(EditorSearch.findMatches(text, 'foo', wholeWord: true), [0, 4]);
    });

    test('wraps next and previous around the matches', () {
      final search = EditorSearch()..run('a a a', 'a');

      expect(search.currentIndex, 0);
      expect(search.previousIndex, 2);
      search.currentIndex = 2;
      expect(search.nextIndex, 0);

      search.run('a a a', '');
      expect(search.hasMatches, false);
      expect(search.currentIndex, EditorSearch.noMatch);
    });
  });

  group('CodeFormatter', () {
    test('formats JSON and ARB only alongside Dart', () {
      expect(CodeFormatter.canFormat('a/b.dart'), true);
      expect(CodeFormatter.canFormat('a/app_en.ARB'), true);
      expect(CodeFormatter.canFormat('a/b.yaml'), false);
    });

    test('formats the given text, not the file on disk', () async {
      const formatter = CodeFormatter(ProcessRunner());

      expect(await formatter.format('app_en.arb', '{"a":1}'), '{\n  "a": 1\n}');
      expect(
        await formatter.format('lib/x.dart', 'void main(){print(1);}'),
        'void main() {\n  print(1);\n}\n',
      );
      await expectLater(
        formatter.format('lib/x.dart', 'void main( {'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
