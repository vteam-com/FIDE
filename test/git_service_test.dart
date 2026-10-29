import 'dart:io';

import 'package:fide/providers/git_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Runs git in [dir], failing the test on a non-zero exit
void _git(String dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  late Directory repo;
  late String nestedFile;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('fide_git_');
    _git(repo.path, ['init', '-q']);
    _git(repo.path, ['config', 'user.email', 'test@example.com']);
    _git(repo.path, ['config', 'user.name', 'Test']);

    // A file below the repo root catches repo-relative path mistakes
    Directory(path.join(repo.path, 'lib')).createSync();
    nestedFile = path.join(repo.path, 'lib', 'main.dart');
    File(nestedFile).writeAsStringSync('committed\n');
    _git(repo.path, ['add', '.']);
    _git(repo.path, ['commit', '-q', '-m', 'init']);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  test('getHeadContent reads a nested file by absolute path', () async {
    File(nestedFile).writeAsStringSync('edited\n');

    expect(await const GitService().getHeadContent(nestedFile), 'committed\n');
  });

  test('getHeadContent is empty for files not in HEAD', () async {
    final newFile = path.join(repo.path, 'lib', 'new.dart');
    File(newFile).writeAsStringSync('new\n');

    expect(await const GitService().getHeadContent(newFile), '');
  });

  test('getStagedContent reads the index, not the working copy', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', 'lib/main.dart']);
    File(nestedFile).writeAsStringSync('working\n');

    expect(await const GitService().getStagedContent(nestedFile), 'staged\n');
  });

  test('getFileDiff is empty for an unchanged tracked file', () async {
    expect(await const GitService().getFileDiff(repo.path, nestedFile), '');
  });

  test('getFileDiff shows staged and unstaged edits against HEAD', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', 'lib/main.dart']);
    File(nestedFile).writeAsStringSync('working\n');

    final diff = await const GitService().getFileDiff(repo.path, nestedFile);

    expect(diff, contains('-committed'));
    expect(diff, contains('+working'));
  });

  test('getFileDiff shows an untracked file as added', () async {
    final newFile = path.join(repo.path, 'lib', 'new.dart');
    File(newFile).writeAsStringSync('new\n');

    final diff = await const GitService().getFileDiff(repo.path, newFile);

    expect(diff, contains('+new'));
  });

  test('a failing mutation throws GitException', () async {
    expect(
      const GitService().commit(repo.path, 'nothing to commit'),
      throwsA(isA<GitException>()),
    );
  });
}
