import 'dart:io';

import 'package:fide/models/document_state.dart';
import 'package:fide/models/editor_diff_outcome.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/panels/center/editor/editor_session.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_code_formatter.dart';
import 'fake_file_content_reader.dart';

/// A git whose HEAD content is set by the test.
class _FakeGit extends GitService {
  _FakeGit() : super(const ProcessRunner());

  String? headText;

  @override
  Future<({String oldText, String newText})?> diffAgainstHead(
    String filePath, {
    String? newText,
  }) async {
    final oldText = headText;
    if (oldText == null) return null;
    return (oldText: oldText, newText: newText!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const path = '/project/lib/main.dart';
  late FakeFileContentReader reader;
  late _FakeGit git;
  late OpenDocumentsNotifier documents;
  late EditorSession session;
  late int changes;

  setUp(() async {
    reader = FakeFileContentReader()..files[path] = 'void main() {}\n';
    git = _FakeGit();
    documents = OpenDocumentsNotifier(reader: reader);
    await documents.open(path);
    changes = 0;
    session = EditorSession(
      documents: documents,
      formatter: const FakeCodeFormatter(),
      git: git,
    )..addListener(() => changes++);
    session.load(documents.state.active!);
  });

  test('load shows the document clean, without publishing an edit', () {
    expect(session.filePath, path);
    expect(session.code.text, 'void main() {}\n');
    expect(session.isDirty, isFalse);
    expect(session.savedText, 'void main() {}\n');
    expect(session.cursor, (line: 1, column: 1));
    expect(session.canFormat, isTrue);
    expect(changes, 0);
  });

  test('an edit marks the text dirty and publishes it', () {
    session.code.text = 'void main() {}\n// edited\n';

    expect(session.isDirty, isTrue);
    expect(changes, 1);
    expect(documents.state.active!.content, 'void main() {}\n// edited\n');
    expect(documents.state.active!.isDirty, isTrue);

    session.code.text = 'void main() {}\n';
    expect(session.isDirty, isFalse);
  });

  test('a caret move tells listeners but publishes no document', () {
    final published = <OpenDocuments>[];
    documents.addListener(published.add, fireImmediately: false);

    session.code.selection = const TextSelection.collapsed(offset: 5);

    expect(changes, 1);
    expect(session.cursor, (line: 1, column: 6));
    expect(published, isEmpty);
  });

  test('an edit publishes the text and the selection once', () {
    final published = <OpenDocuments>[];
    documents.addListener(published.add, fireImmediately: false);

    session.code.insertAtCurrentCursor('// ');

    expect(published, hasLength(1));
    expect(published.single.active!.content, '// void main() {}\n');
    expect(published.single.active!.selection, session.code.selection);
  });

  test('leaving the file publishes the caret moved since', () async {
    const other = '/project/lib/other.dart';
    reader.files[other] = 'other\n';
    await documents.open(other);
    session.code.selection = const TextSelection.collapsed(offset: 5);

    session.load(documents.state.active!);
    // Published after the build that switched files
    expect(documents.state.documentOf(path)!.selection.baseOffset, 0);
    await Future<void>.delayed(Duration.zero);

    expect(
      documents.state.documentOf(path)!.selection,
      const TextSelection.collapsed(offset: 5),
    );
    expect(session.filePath, other);
  });

  test('dispose publishes the caret moved since', () async {
    session.code.selection = const TextSelection.collapsed(offset: 7);

    session.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(
      documents.state.active!.selection,
      const TextSelection.collapsed(offset: 7),
    );
  });

  test('a caret past the end of the text loads at its end', () {
    session.load(
      const DocumentState(
        filePath: path,
        content: 'ab',
        selection: TextSelection.collapsed(offset: 99),
      ),
    );

    expect(session.code.selection, const TextSelection.collapsed(offset: 2));
    expect(session.cursor, (line: 1, column: 3));
  });

  test('cursor matches TextOffsets.positionOf at every offset', () {
    for (final text in ['', 'a', '\n', 'ab\ncde\n\nf', 'x\r\ny\n', '\n\n']) {
      session.load(DocumentState(filePath: path, content: text));
      for (var offset = 0; offset <= text.length; offset++) {
        session.restoreSelection(TextSelection.collapsed(offset: offset));
        expect(
          session.cursor,
          TextOffsets.positionOf(text, offset),
          reason: 'offset $offset of ${text.codeUnits}',
        );
      }
    }
  });

  test('restoreSelection moves the caret without publishing', () {
    session.restoreSelection(const TextSelection.collapsed(offset: 5));

    expect(session.cursor, (line: 1, column: 6));
    expect(changes, 0);
  });

  test('save writes the text and records it as saved', () async {
    session.code.text = 'edited\n';

    await session.save();

    expect(reader.files[path], 'edited\n');
    expect(session.savedText, 'edited\n');
    expect(session.isDirty, isFalse);
    expect(documents.state.active!.isDirty, isFalse);
  });

  test('save throws when the write fails and stays dirty', () async {
    session.code.text = 'edited\n';
    reader.failWrites = true;

    await expectLater(session.save(), throwsA(isA<FileSystemException>()));

    expect(session.isDirty, isTrue);
  });

  test('format returns the formatted text without applying it', () async {
    session.code.text = 'edited\n\n\n';

    expect(await session.format(), 'edited\n');
    expect(session.code.text, 'edited\n\n\n');
  });

  test('loadDiff reports the outcome and keeps a loaded diff', () async {
    expect(await session.loadDiff(), EditorDiffOutcome.notGitRepository);
    expect(session.diff, isNull);

    git.headText = 'void main() {}\n';
    expect(await session.loadDiff(), EditorDiffOutcome.unchanged);
    expect(session.diff, isNull);

    session.code.text = 'edited\n';
    expect(await session.loadDiff(), EditorDiffOutcome.loaded);
    expect(session.diff, (oldText: 'void main() {}\n', newText: 'edited\n'));

    session.clearDiff();
    expect(session.diff, isNull);
  });

  test('dispose writes unsaved edits at once', () {
    session.code.text = 'edited on close\n';

    session.dispose();

    expect(reader.syncWrites, 1);
    expect(reader.files[path], 'edited on close\n');
  });

  test('dispose writes nothing when the text is saved', () {
    session.dispose();

    expect(reader.syncWrites, 0);
  });
}
