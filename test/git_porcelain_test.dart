import 'package:fide/models/git_file_status.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitPorcelain.parseStatus', () {
    test('reads codes and paths, renames at their new path', () {
      final entries = GitPorcelain.parseStatus(
        'M  lib/a.dart\n M lib/b.dart\n?? new/\nR  old.txt -> new.txt\n\nx\n',
      );

      expect(entries, [
        (code: 'M ', path: 'lib/a.dart', movedFrom: null),
        (code: ' M', path: 'lib/b.dart', movedFrom: null),
        (code: '??', path: 'new/', movedFrom: null),
        (code: 'R ', path: 'new.txt', movedFrom: 'old.txt'),
      ]);
    });
  });

  group('GitPorcelain.classify', () {
    test('files entries by their staged and unstaged letters', () {
      final status = GitStatus(staged: [], unstaged: [], untracked: []);

      GitPorcelain.classify('A ', 'added.txt', status);
      GitPorcelain.classify(' D', 'gone.txt', status);
      GitPorcelain.classify('MM', 'both.txt', status);
      GitPorcelain.classify('??', 'new.txt', status);

      expect(status.staged, ['added.txt', 'both.txt']);
      expect(status.unstaged, ['gone.txt', 'both.txt']);
      expect(status.untracked, ['new.txt']);
      expect(status.stagedKinds['added.txt'], GitFileStatus.added);
      expect(status.unstagedKinds['gone.txt'], GitFileStatus.deleted);
      expect(status.unstagedKinds['both.txt'], GitFileStatus.modified);
    });

    test('files a rename with where it moved from, on its side', () {
      final status = GitStatus(staged: [], unstaged: [], untracked: []);

      GitPorcelain.classify('RM', 'lib/b.dart', status, movedFrom: 'a.dart');

      expect(status.stagedKinds['lib/b.dart'], GitFileStatus.renamed);
      expect(status.stagedMovedFrom, {'lib/b.dart': 'a.dart'});
      expect(status.unstagedKinds['lib/b.dart'], GitFileStatus.modified);
      expect(status.unstagedMovedFrom, isEmpty);
    });

    test('kindOf treats anything but A, D and R as modified', () {
      expect(GitPorcelain.kindOf('A'), GitFileStatus.added);
      expect(GitPorcelain.kindOf('D'), GitFileStatus.deleted);
      expect(GitPorcelain.kindOf('R'), GitFileStatus.renamed);
      expect(GitPorcelain.kindOf('C'), GitFileStatus.modified);
    });
  });

  group('GitStatus moves', () {
    GitStatus movedStatus() {
      final status = GitStatus(staged: [], unstaged: [], untracked: []);
      GitPorcelain.classify(' D', 'a.dart', status);
      GitPorcelain.classify(' M', 'c.dart', status);
      GitPorcelain.classify('??', 'lib/a.dart', status);
      GitPorcelain.classify('??', 'other.dart', status);
      return status;
    }

    test('addMove makes a deletion and an untracked file one rename', () {
      final status = movedStatus();

      expect(status.mayHaveMoves, isTrue);
      status.addMove('a.dart', 'lib/a.dart');

      expect(status.unstaged, ['lib/a.dart', 'c.dart']);
      expect(status.unstagedKinds, {
        'lib/a.dart': GitFileStatus.renamed,
        'c.dart': GitFileStatus.modified,
      });
      expect(status.unstagedMovedFrom, {'lib/a.dart': 'a.dart'});
      expect(status.untracked, ['other.dart']);
      expect(status.statusOf('lib/a.dart'), GitFileStatus.renamed);
      expect(status.mayHaveMoves, isFalse);
    });

    test('addMove pairs only a deletion with an untracked file', () {
      final status = movedStatus()
        ..addMove('c.dart', 'other.dart')
        ..addMove('a.dart', 'c.dart');

      expect(status.unstaged, ['a.dart', 'c.dart']);
      expect(status.untracked, ['lib/a.dart', 'other.dart']);
      expect(status.unstagedMovedFrom, isEmpty);
    });

    test('headPathOf follows an unstaged move, then a staged one', () {
      final status = GitStatus(staged: [], unstaged: [], untracked: []);
      GitPorcelain.classify('RD', 'b.dart', status, movedFrom: 'a.dart');
      GitPorcelain.classify('??', 'c.dart', status);
      status.addMove('b.dart', 'c.dart');

      expect(status.headPathOf('c.dart'), 'a.dart');
      expect(status.headPathOf('b.dart'), 'a.dart');
      expect(status.headPathOf('a.dart'), isNull);
    });
  });

  group('GitPorcelain.parseCommit', () {
    test('reads the hash, date and tabbed subject, flagging unpushed', () {
      final commit = GitPorcelain.parseCommit('abc\t1700000000\tone\ttwo', {
        'abc',
      });

      expect(commit!.hash, 'abc');
      expect(commit.message, 'one\ttwo');
      expect(
        commit.date,
        DateTime.fromMillisecondsSinceEpoch(
          1700000000 * Duration.millisecondsPerSecond,
        ),
      );
      expect(commit.isUnpushed, isTrue);
    });

    test('rejects lines of another shape', () {
      expect(GitPorcelain.parseCommit('abc\tsubject', {}), isNull);
      expect(GitPorcelain.parseCommit('abc\tsoon\tsubject', {}), isNull);
    });
  });

  test('parseSyncCounts reads ahead and behind, zero without both', () {
    expect(GitPorcelain.parseSyncCounts('2\t1\n'), (ahead: 2, behind: 1));
    expect(GitPorcelain.parseSyncCounts(null), (ahead: 0, behind: 0));
    expect(GitPorcelain.parseSyncCounts('3'), (ahead: 0, behind: 0));
  });

  test('parseVersion picks the version number out of git --version', () {
    expect(
      GitPorcelain.parseVersion('git version 2.39.3 (Apple Git-145)'),
      '2.39.3',
    );
    expect(GitPorcelain.parseVersion('weird'), isNull);
  });

  group('GitException', () {
    test('explains the failed attempt with the details when there are', () {
      const failed = GitException('git push', ' rejected \n');
      expect(
        failed.explain('Failed to push changes'),
        'Failed to push changes: rejected',
      );
      expect(failed.toString(), 'git push: rejected');
      expect(
        const GitException('git push').explain('Failed to push changes'),
        'Failed to push changes',
      );
    });
  });
}
