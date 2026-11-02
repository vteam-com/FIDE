import 'package:code_forge/code_forge.dart';
import 'package:fide/models/editor_search.dart';
import 'package:fide/panels/center/editor/editor_search_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CodeForgeController code;
  late EditorSearchController search;
  late int selected;

  setUp(() {
    selected = 0;
    code = CodeForgeController()
      ..text = 'foo bar foo baz foo'
      ..selection = const TextSelection.collapsed(offset: 0);
    search = EditorSearchController(code, onMatchSelected: () => selected++);
  });

  tearDown(() {
    search.dispose();
    code.dispose();
  });

  group('EditorSearchController', () {
    test('open seeds the query from the selection and selects it', () {
      code.selection = const TextSelection(baseOffset: 8, extentOffset: 11);

      search.open();

      expect(search.isOpen, isTrue);
      expect(search.queryController.text, 'foo');
      expect(search.matchCount, 3);
      expect(search.currentIndex, 1);
      expect(
        code.selection,
        const TextSelection(baseOffset: 8, extentOffset: 11),
      );
      expect(selected, 1);
    });

    test('findNext and findPrevious wrap around the matches', () {
      search.search('foo');

      expect(search.findNext(), isTrue);
      expect(code.selection.start, 8);
      search.findNext();
      expect(code.selection.start, 16);
      search.findNext();
      expect(code.selection.start, 0);
      search.findPrevious();
      expect(code.selection.start, 16);
    });

    test('findNext without a query or selection opens the find bar', () {
      expect(search.findNext(), isFalse);
      expect(search.isOpen, isTrue);
    });

    test('close keeps the query for findNext', () {
      search
        ..open()
        ..search('bar')
        ..close();

      expect(search.isOpen, isFalse);
      code.selection = const TextSelection.collapsed(offset: 0);
      expect(search.findNext(), isTrue);
      expect(code.selection.start, 4);
    });

    test('options narrow the matches', () {
      code.text = 'Foo foo food';
      search.search('foo');
      expect(search.matchCount, 3);

      search.setCaseSensitive(true);
      expect(search.matchCount, 2);

      search.setWholeWord(true);
      expect(search.matchCount, 1);
      expect((search.caseSensitive, search.wholeWord), (true, true));
    });

    test('replace swaps the current match and moves on', () {
      search.search('foo');
      search.replaceController.text = 'qux';

      search.replace();

      expect(code.text, 'qux bar foo baz foo');
      expect(search.matchCount, 2);
      expect(code.selection.start, 8);
    });

    test('replaceAll replaces every match and counts them', () {
      search.search('foo');
      search.replaceController.text = 'x';

      expect(search.replaceAll(), 3);
      expect(code.text, 'x bar x baz x');
      expect(search.currentIndex, EditorSearch.noMatch);
    });

    test('notifies listeners of changes', () {
      var notified = 0;
      search.addListener(() => notified++);

      search.toggle();
      search.toggle();

      expect(search.isOpen, isFalse);
      expect(notified, greaterThanOrEqualTo(2));
    });
  });
}
