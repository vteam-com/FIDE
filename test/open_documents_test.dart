import 'dart:io';

import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_history.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    test('opens an unsupported text file as plain text', () async {
      final path = write('notes.xyz');
      await documents.open(path);

      expect(await documents.openAsPlainText(path), isTrue);

      expect(current.active!.asPlainText, isTrue);
      expect(current.active!.content, '// notes.xyz');
    });

    test('refuses to open a binary file as plain text', () async {
      final path = p.join(project.path, 'blob.bin');
      File(path).writeAsBytesSync(const [0xff, 0xfe, 0x00, 0xc3]);
      await documents.open(path);

      expect(await documents.openAsPlainText(path), isFalse);

      expect(current.active!.asPlainText, isFalse);
    });
  });

  group('DocumentState equality', () {
    const document = DocumentState(filePath: 'a.dart', content: 'abc');

    test('equal by value, the text compared once not identical', () {
      final sameText = DocumentState(
        filePath: 'a.dart',
        content: ['a', 'b', 'c'].join(),
      );

      expect(sameText, document);
      expect(sameText.hashCode, document.hashCode);
      expect(document.copyWith(content: 'abd'), isNot(document));
      expect(document.copyWith(isDirty: true), isNot(document));
      expect(
        document.copyWith(selection: const TextSelection.collapsed(offset: 1)),
        isNot(document),
      );
      expect(document.toPlainText(), isNot(document));
    });
  });

  group('Watching the open documents', () {
    late Directory project;
    late ProviderContainer container;
    late String a;
    late String b;

    setUp(() async {
      project = Directory.systemTemp.createTempSync('fide_watch_');
      a = p.join(project.path, 'a.dart');
      b = p.join(project.path, 'b.dart');
      File(a).writeAsStringSync('// a');
      File(b).writeAsStringSync('// b');
      container = ProviderContainer();
      final documents = container.read(openDocumentsProvider.notifier);
      await documents.open(a);
      await documents.open(b);
    });
    tearDown(() {
      container.dispose();
      project.deleteSync(recursive: true);
    });

    test('an update changing nothing publishes no state', () {
      final states = <OpenDocuments>[];
      container.listen(openDocumentsProvider, (_, next) => states.add(next));
      final documents = container.read(openDocumentsProvider.notifier);

      documents.update(b, content: ['// ', 'b'].join(), isDirty: false);

      expect(states, isEmpty);
    });

    test('tabs change with the files open, not with their text', () {
      final tabs = <OpenDocumentTabs>[];
      container.listen(
        openDocumentsProvider.select((d) => d.tabs),
        (_, next) => tabs.add(next),
      );
      final documents = container.read(openDocumentsProvider.notifier);

      documents.update(b, content: '// edited', isDirty: true);
      expect(tabs, isEmpty);

      documents.activate(0);
      expect(tabs, [
        OpenDocumentTabs(filePaths: [a, b], activeIndex: 0),
      ]);
    });

    test('documentOf finds an open document by path', () {
      final state = container.read(openDocumentsProvider);

      expect(state.documentOf(a)?.content, '// a');
      expect(state.documentOf('missing.dart'), isNull);
    });
  });
}
