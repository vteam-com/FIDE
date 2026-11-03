import 'dart:io';

import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
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

    expect(
      await const GitService(ProcessRunner()).getHeadContent(nestedFile),
      'committed\n',
    );
  });

  test('getHeadContent is empty for files not in HEAD', () async {
    final newFile = path.join(repo.path, 'lib', 'new.dart');
    File(newFile).writeAsStringSync('new\n');

    expect(await const GitService(ProcessRunner()).getHeadContent(newFile), '');
  });

  test('getBytesAt reads binary content from HEAD and the index', () async {
    final image = path.join(repo.path, 'lib', 'pixel.bin');
    File(image).writeAsBytesSync([0, 255, 10, 0, 13, 0]);
    _git(repo.path, ['add', '.']);
    _git(repo.path, ['commit', '-q', '-m', 'binary']);
    File(image).writeAsBytesSync([1, 2]);
    _git(repo.path, ['add', '.']);
    File(image).writeAsBytesSync([3]);
    const git = GitService(ProcessRunner());

    expect(await git.getBytesAt(image), [0, 255, 10, 0, 13, 0]);
    expect(await git.getBytesAt(image, revision: GitService.indexRevision), [
      1,
      2,
    ]);
    expect(await git.getBytesAt(path.join(repo.path, 'missing.bin')), isNull);
  });

  test('a changed binary file has changes without line counts', () async {
    final image = path.join(repo.path, 'lib', 'pixel.bin');
    File(image).writeAsBytesSync([0, 255, 10, 0, 13, 0]);
    _git(repo.path, ['add', '.']);
    _git(repo.path, ['commit', '-q', '-m', 'binary']);
    File(image).writeAsBytesSync([0, 255, 10, 0, 13, 1]);

    final stats = await const GitService(ProcessRunner())
        .getFileDiffStats(repo.path, image);

    expect(stats.isBinary, isTrue);
    expect(stats.hasChanges, isTrue);
    expect((stats.added, stats.removed), (0, 0));
  });

  test('getStagedContent reads the index, not the working copy', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', 'lib/main.dart']);
    File(nestedFile).writeAsStringSync('working\n');

    expect(
      await const GitService(ProcessRunner()).getStagedContent(nestedFile),
      'staged\n',
    );
  });

  test('getFileDiff is empty for an unchanged tracked file', () async {
    expect(
      await const GitService(ProcessRunner())
          .getFileDiff(repo.path, nestedFile),
      '',
    );
  });

  test('getFileDiff shows staged and unstaged edits against HEAD', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', 'lib/main.dart']);
    File(nestedFile).writeAsStringSync('working\n');

    final diff = await const GitService(ProcessRunner())
        .getFileDiff(repo.path, nestedFile);

    expect(diff, contains('-committed'));
    expect(diff, contains('+working'));
  });

  test('getFileDiff shows an untracked file as added', () async {
    final newFile = path.join(repo.path, 'lib', 'new.dart');
    File(newFile).writeAsStringSync('new\n');

    final diff = await const GitService(ProcessRunner())
        .getFileDiff(repo.path, newFile);

    expect(diff, contains('+new'));
  });

  test('a failing mutation throws GitException', () async {
    expect(
      const GitService(ProcessRunner()).commit(repo.path, 'nothing to commit'),
      throwsA(isA<GitException>()),
    );
  });

  test('canAmend is true for an unpushed commit', () async {
    expect(await const GitService(ProcessRunner()).canAmend(repo.path), isTrue);
  });

  test('canAmend is false once the commit is on a remote branch', () async {
    final remote = Directory.systemTemp.createTempSync('fide_git_remote_');
    addTearDown(() => remote.deleteSync(recursive: true));
    _git(remote.path, ['init', '-q', '--bare']);
    _git(repo.path, ['remote', 'add', 'origin', remote.path]);
    _git(repo.path, ['push', '-q', 'origin', 'HEAD']);

    expect(
      await const GitService(ProcessRunner()).canAmend(repo.path),
      isFalse,
    );
  });

  test('amend with an empty message keeps the last commit message', () async {
    File(nestedFile).writeAsStringSync('amended\n');
    _git(repo.path, ['add', 'lib/main.dart']);

    await const GitService(ProcessRunner()).amend(repo.path, '');

    final commits = await const GitService(ProcessRunner())
        .getRecentCommits(repo.path);
    expect(commits.map((c) => c.message), ['init']);
    expect(
      await const GitService(ProcessRunner()).getHeadContent(nestedFile),
      'amended\n',
    );
  });

  test('amend with a message rewords the last commit', () async {
    await const GitService(ProcessRunner()).amend(repo.path, 'reworded');

    final commits = await const GitService(ProcessRunner())
        .getRecentCommits(repo.path);
    expect(commits.map((c) => c.message), ['reworded']);
  });

  test('staged diff names staged files and leaves out unstaged ones', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', '.']);
    File(path.join(repo.path, 'other.txt')).writeAsStringSync('unstaged\n');

    final diff = await const GitService(ProcessRunner())
        .getStagedDiff(repo.path);

    expect(diff, contains('lib/main.dart'));
    expect(diff, contains('+staged'));
    expect(diff, isNot(contains('other.txt')));
  });

  test(
    'syncCounts reports commits to push and, after a fetch, to pull',
    () async {
      const git = GitService(ProcessRunner());
      expect(await git.syncCounts(repo.path), (ahead: 0, behind: 0));

      final remote = Directory.systemTemp.createTempSync('fide_git_remote_');
      final other = Directory.systemTemp.createTempSync('fide_git_other_');
      addTearDown(() {
        remote.deleteSync(recursive: true);
        other.deleteSync(recursive: true);
      });
      _git(remote.path, ['init', '-q', '--bare']);
      _git(repo.path, ['remote', 'add', 'origin', remote.path]);
      _git(repo.path, ['push', '-q', '-u', 'origin', 'HEAD']);

      File(nestedFile).writeAsStringSync('local\n');
      _git(repo.path, ['commit', '-qam', 'local']);
      expect(await git.syncCounts(repo.path), (ahead: 1, behind: 0));

      // Another clone pushes a commit this repo hasn't fetched yet
      _git(other.path, ['clone', '-q', remote.path, '.']);
      _git(other.path, ['config', 'user.email', 'test@example.com']);
      _git(other.path, ['config', 'user.name', 'Test']);
      File(path.join(other.path, 'remote.txt')).writeAsStringSync('remote\n');
      _git(other.path, ['add', '.']);
      _git(other.path, ['commit', '-qm', 'remote']);
      _git(other.path, ['push', '-q']);

      expect(await git.fetch(repo.path), isTrue);
      expect(await git.syncCounts(repo.path), (ahead: 1, behind: 1));
    },
  );

  test('getStatus tells added, modified and deleted files apart', () async {
    File(path.join(repo.path, 'added.txt')).writeAsStringSync('a\n');
    File(path.join(repo.path, 'gone.txt')).writeAsStringSync('g\n');
    _git(repo.path, ['add', '.']);
    _git(repo.path, ['commit', '-q', '-m', 'more']);
    File(path.join(repo.path, 'new.txt')).writeAsStringSync('n\n');
    _git(repo.path, ['add', 'new.txt']);
    File(path.join(repo.path, 'gone.txt')).deleteSync();
    File(nestedFile).writeAsStringSync('edited\n');

    final status = await const GitService(ProcessRunner()).getStatus(repo.path);

    expect(status.stagedKinds, {'new.txt': GitFileStatus.added});
    expect(status.unstagedKinds, {
      'gone.txt': GitFileStatus.deleted,
      'lib/main.dart': GitFileStatus.modified,
    });
    expect(status.statusOf('new.txt'), GitFileStatus.added);
    expect(status.statusOf('lib/main.dart'), GitFileStatus.modified);
  });

  test('getChangeStats counts lines per staged and unstaged file', () async {
    File(nestedFile).writeAsStringSync('one\ntwo\n');
    _git(repo.path, ['add', '.']);
    File(path.join(repo.path, 'new.txt')).writeAsStringSync('x\ny\nz');
    const git = GitService(ProcessRunner());

    final stats = await git.getChangeStats(
      repo.path,
      await git.getStatus(repo.path),
    );

    final staged = stats.staged['lib/main.dart']!;
    expect((staged.added, staged.removed), (2, 1));
    expect(stats.unstaged['new.txt']!.added, 3);
  });

  test(
    'getChangeStats counts an untracked binary file as zero lines',
    () async {
      // Not valid UTF-8, like the bytes of a PNG
      File(path.join(repo.path, 'image.png')).writeAsBytesSync([0x89, 0xff]);
      const git = GitService(ProcessRunner());

      final stats = await git.getChangeStats(
        repo.path,
        await git.getStatus(repo.path),
      );

      expect(stats.unstaged['image.png']!.added, 0);
    },
  );

  test('getRecentCommits dates commits and flags unpushed ones', () async {
    final remote = Directory.systemTemp.createTempSync('fide_git_remote_');
    addTearDown(() => remote.deleteSync(recursive: true));
    _git(remote.path, ['init', '-q', '--bare']);
    _git(repo.path, ['remote', 'add', 'origin', remote.path]);
    _git(repo.path, ['push', '-q', '-u', 'origin', 'HEAD']);
    File(nestedFile).writeAsStringSync('local\n');
    _git(repo.path, ['commit', '-q', '-am', 'local only']);

    final commits = await const GitService(ProcessRunner())
        .getRecentCommits(repo.path);

    expect(commits.map((c) => (c.message, c.isUnpushed)), [
      ('local only', true),
      ('init', false),
    ]);
    expect(
      DateTime.now().difference(commits.first.date),
      lessThan(const Duration(minutes: 1)),
    );
  });

  test(
    'getFileDiffStats counts staged and unstaged edits against HEAD',
    () async {
      File(nestedFile).writeAsStringSync('staged\n');
      _git(repo.path, ['add', 'lib/main.dart']);
      File(nestedFile).writeAsStringSync('staged\nworking\n');

      final stats = await const GitService(ProcessRunner())
          .getFileDiffStats(path.dirname(nestedFile), nestedFile);

      expect((stats.added, stats.removed, stats.isNewFile), (2, 1, false));
    },
  );

  test('getFileDiffStats is zero for an unchanged file', () async {
    final stats = await const GitService(ProcessRunner())
        .getFileDiffStats(path.dirname(nestedFile), nestedFile);

    expect(stats.hasChanges, isFalse);
  });

  test('diffAgainstHead pairs HEAD with the given text', () async {
    final diff = await const GitService(ProcessRunner())
        .diffAgainstHead(nestedFile, newText: 'buffer\n');

    expect((diff!.oldText, diff.newText), ('committed\n', 'buffer\n'));
  });

  test('diffAgainstHead reads the index or the working copy', () async {
    File(nestedFile).writeAsStringSync('staged\n');
    _git(repo.path, ['add', 'lib/main.dart']);
    File(nestedFile).writeAsStringSync('working\n');
    const git = GitService(ProcessRunner());

    final staged = await git.diffAgainstHead(nestedFile, staged: true);
    final working = await git.diffAgainstHead(nestedFile);

    expect(staged!.newText, 'staged\n');
    expect(working!.newText, 'working\n');
  });

  test('diffAgainstHead is null outside a repository', () async {
    final outside = Directory.systemTemp.createTempSync('fide_no_git_');
    addTearDown(() => outside.deleteSync(recursive: true));
    final file = File(path.join(outside.path, 'a.txt'))..writeAsStringSync('a');

    expect(
      await const GitService(ProcessRunner()).diffAgainstHead(file.path),
      isNull,
    );
  });

  group('GitDiffStats.parseNumstat', () {
    test('reads added and removed lines per path', () {
      final stats = GitDiffStats.parseNumstat(
        '3\t1\tlib/a.dart\n0\t2\tb.txt\n',
      );

      expect(stats.map((file, s) => MapEntry(file, (s.added, s.removed))), {
        'lib/a.dart': (3, 1),
        'b.txt': (0, 2),
      });
    });

    test('counts binary files as changed without lines', () {
      final stats = GitDiffStats.parseNumstat('-\t-\timage.png');

      expect(stats['image.png']!.isBinary, isTrue);
      expect(stats['image.png']!.hasChanges, isTrue);
      expect(stats['image.png']!.added, 0);
    });

    test('keeps tabs in paths and skips malformed lines', () {
      final stats = GitDiffStats.parseNumstat('1\t0\ta\tb\n\nnot numstat\n');

      expect(stats.keys, ['a\tb']);
    });
  });
}
