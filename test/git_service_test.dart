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

  test('canAmend is true for an unpushed commit', () async {
    expect(await const GitService().canAmend(repo.path), isTrue);
  });

  test('canAmend is false once the commit is on a remote branch', () async {
    final remote = Directory.systemTemp.createTempSync('fide_git_remote_');
    addTearDown(() => remote.deleteSync(recursive: true));
    _git(remote.path, ['init', '-q', '--bare']);
    _git(repo.path, ['remote', 'add', 'origin', remote.path]);
    _git(repo.path, ['push', '-q', 'origin', 'HEAD']);

    expect(await const GitService().canAmend(repo.path), isFalse);
  });

  test('amend with an empty message keeps the last commit message', () async {
    File(nestedFile).writeAsStringSync('amended\n');
    _git(repo.path, ['add', 'lib/main.dart']);

    await const GitService().amend(repo.path, '');

    final commits = await const GitService().getRecentCommits(repo.path);
    expect(commits.map((c) => c.message), ['init']);
    expect(await const GitService().getHeadContent(nestedFile), 'amended\n');
  });

  test('amend with a message rewords the last commit', () async {
    await const GitService().amend(repo.path, 'reworded');

    final commits = await const GitService().getRecentCommits(repo.path);
    expect(commits.map((c) => c.message), ['reworded']);
  });

  test('staged diff names staged files and leaves out unstaged ones', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', '.']);
    File(path.join(repo.path, 'other.txt')).writeAsStringSync('unstaged\n');

    final diff = await const GitService().getStagedDiff(repo.path);

    expect(diff, contains('lib/main.dart'));
    expect(diff, contains('+staged'));
    expect(diff, isNot(contains('other.txt')));
  });
}
