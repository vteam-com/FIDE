import 'dart:io';

import 'package:fide/models/open_documents.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/editor_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// An editor that saves the showing document's latest content through the
/// notifier, as the real one does.
class _SavingEditor implements EditorCommands {
  late OpenDocumentsNotifier documents;
  late OpenDocuments Function() current;
  int saves = 0;

  @override
  Future<void> save() async {
    saves++;
    final active = current().active!;
    await documents.save(active.filePath, active.content);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory project;
  late _SavingEditor editor;
  late OpenDocumentsNotifier documents;
  late int savedCount;
  late OpenDocuments current;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_edits_');
    editor = _SavingEditor();
    savedCount = 0;
    documents = OpenDocumentsNotifier(
      onSaved: (_) => savedCount++,
      activeEditor: editor,
    );
    editor.documents = documents;
    editor.current = () => current;
    documents.addListener((state) => current = state);
  });
  tearDown(() => project.deleteSync(recursive: true));

  String write(String name, String content) {
    final path = p.join(project.path, name);
    File(path).writeAsStringSync(content);
    return path;
  }

  test('writes the files, reloads them and notifies the save', () async {
    final a = write('a.dart', 'class A {}');
    await documents.open(a);

    final files = await documents.applyEdits(() async => {a: 'class B {}'});

    expect(files, {a: 'class B {}'});
    expect(File(a).readAsStringSync(), 'class B {}');
    expect(current.active!.content, 'class B {}');
    expect(savedCount, 1);
  });

  test('saves unsaved documents before computing the edit', () async {
    final a = write('a.dart', 'class A {}');
    final b = write('b.dart', 'class Old {}');
    await documents.open(b);
    documents.update(b, content: 'class Typed {}', isDirty: true);
    await documents.open(a);
    documents.update(a, content: 'class Shown {}', isDirty: true);

    final seen = <String, String>{};
    await documents.applyEdits(() async {
      seen[a] = File(a).readAsStringSync();
      seen[b] = File(b).readAsStringSync();
      return const {};
    });

    expect(seen, {a: 'class Shown {}', b: 'class Typed {}'});
    expect(editor.saves, 1);
    expect(current.documents.any((d) => d.isDirty), false);
  });

  test('writes nothing when a file is edited while computing', () async {
    final a = write('a.dart', 'class A {}');
    await documents.open(a);

    await expectLater(
      documents.applyEdits(() async {
        documents.update(a, content: 'class Typing {}', isDirty: true);
        return {a: 'class B {}'};
      }),
      throwsStateError,
    );
    expect(File(a).readAsStringSync(), 'class A {}');
  });

  test('a move writes the file at its new place, deletes it where it was '
      'with its emptied folder, and keeps its tab, showing it there', () async {
    Directory(p.join(project.path, 'screens')).createSync();
    final card = write(p.join('screens', 'card.dart'), 'class Card {}');
    final other = write('other.dart', 'class Other {}');
    final moved = p.join(project.path, 'widgets', 'card.dart');
    await documents.open(card);
    await documents.open(other);

    await documents.applyMoves({
      card: moved,
    }, () async => {moved: 'class Card {}'});

    expect(File(moved).readAsStringSync(), 'class Card {}');
    expect(File(card).existsSync(), isFalse);
    expect(Directory(p.dirname(card)).existsSync(), isFalse);
    expect([for (final d in current.documents) d.filePath], [moved, other]);
    expect(current.active!.filePath, other);
  });
}
