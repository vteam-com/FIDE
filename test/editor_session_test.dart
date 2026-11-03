import 'dart:io';

import 'package:fide/models/editor_diff_outcome.dart';
import 'package:fide/panels/center/editor/editor_session.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the files written in memory.
class _FakeReader extends FileContentReader {
  final Map<String, String> files = {};

  int syncWrites = 0;

  bool failWrites = false;

  @override
  Future<bool> exists(String filePath) async => files.containsKey(filePath);

  @override
  Future<String> read(String filePath) async => files[filePath]!;

  @override
  Future<void> write(String filePath, String content) async {
    if (failWrites) throw const FileSystemException('read only');
    files[filePath] = content;
  }

  @override
  void writeSync(String filePath, String content) {
    syncWrites++;
    files[filePath] = content;
  }
}

/// Formats by trimming trailing blank lines.
class _FakeFormatter extends CodeFormatter {
  const _FakeFormatter() : super(const ProcessRunner());

  @override
  Future<String> format(String filePath, String content) async =>
      '${content.trimRight()}\n';
}

/// A git whose HEAD content is set by the test.
class _FakeGit extends GitService {
  _FakeGit() : super(const ProcessRunner());

  String? headText;

  @override
  Future<({String oldText, String newText})?> diffAgainstHead(
    String filePath, {
    String? newText,
    bool staged = false,
  }) async {
    final oldText = headText;
    if (oldText == null) return null;
    return (oldText: oldText, newText: newText!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const path = '/project/lib/main.dart';
  late _FakeReader reader;
  late _FakeGit git;
  late OpenDocumentsNotifier documents;
  late EditorSession session;
  late int changes;

  setUp(() async {
    reader = _FakeReader()..files[path] = 'void main() {}\n';
    git = _FakeGit();
    documents = OpenDocumentsNotifier(reader: reader);
    await documents.open(path);
    changes = 0;
    session = EditorSession(
      documents: documents,
      formatter: const _FakeFormatter(),
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
