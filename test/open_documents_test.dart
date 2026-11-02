import 'dart:io';

import 'package:fide/models/file_history.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileHistory', () {
    test('goes back and forward through the visits', () {
      final history = FileHistory.empty.visit('a').visit('b').visit('c');

      expect(history.canGoForward, isFalse);
      final back = history.back().back();
      expect(back.current, 'a');
      expect(back.canGoBack, isFalse);
      expect(back.forward().current, 'b');
    });

    test('a visit after going back forgets the later visits', () {
      final history = FileHistory.empty.visit('a').visit('b').back();

      final visited = history.visit('c');

      expect(visited.paths, ['a', 'c']);
      expect(visited.canGoForward, isFalse);
    });

    test('ignores null and repeated visits', () {
      final history = FileHistory.empty.visit('a');

      expect(history.visit(null), same(history));
      expect(history.visit('a'), same(history));
    });

    test('forgets the oldest visits past its maximum length', () {
      var history = FileHistory.empty;
      for (var i = 0; i <= FileHistory.maxLength; i++) {
        history = history.visit('$i');
      }

      expect(history.paths.length, FileHistory.maxLength);
      expect(history.paths.first, '1');
    });
  });

  group('OpenDocumentsNotifier history', () {
    late Directory project;
    late OpenDocumentsNotifier documents;
    late OpenDocuments current;

    setUp(() {
      project = Directory.systemTemp.createTempSync('fide_history_');
      documents = OpenDocumentsNotifier();
      documents.addListener((state) => current = state);
    });
    tearDown(() => project.deleteSync(recursive: true));

    String write(String name) {
      final path = p.join(project.path, name);
      File(path).writeAsStringSync('// $name');
      return path;
    }

    test('goes back and forward through the shown files', () async {
      final a = write('a.dart');
      final b = write('b.dart');
      await documents.open(a);
      await documents.open(b);

      await documents.goBack();
      expect(current.active?.filePath, a);
      expect(current.history.canGoForward, isTrue);

      await documents.goForward();
      expect(current.active?.filePath, b);
      expect(current.history.canGoForward, isFalse);
    });

    test('switching tabs records a visit', () async {
      final a = write('a.dart');
      final b = write('b.dart');
      await documents.open(a);
      await documents.open(b);

      documents.activate(current.indexOf(a));

      expect(current.history.paths, [a, b, a]);
    });

    test('reloading the showing file records no visit', () async {
      final a = write('a.dart');
      final b = write('b.dart');
      await documents.open(a);
      await documents.open(b);

      await documents.reload([b]);

      expect(current.history.paths, [a, b]);
    });

    test('closing the showing tab shows the next one', () async {
      final a = write('a.dart');
      final b = write('b.dart');
      final c = write('c.dart');
      for (final path in [a, b, c]) {
        await documents.open(path);
      }
      documents.activate(current.indexOf(b));

      await documents.closeActive();
      expect(current.active?.filePath, c);

      await documents.closeActive();
      expect(current.active?.filePath, a);

      await documents.closeActive();
      expect(current.active, isNull);
      expect(current.documents, isEmpty);
    });

    test('closing a tab with unsaved edits saves them', () async {
      final a = write('a.dart');
      await documents.open(a);
      documents.update(a, content: 'edited', isDirty: true);

      await documents.closeActive();

      expect(File(a).readAsStringSync(), 'edited');
    });

    test('closing every tab forgets the history', () async {
      await documents.open(write('a.dart'));

      documents.closeAll();

      expect(current.history.current, isNull);
    });
  });
}
