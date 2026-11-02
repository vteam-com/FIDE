import 'dart:async';
import 'dart:io';

import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Runs git in [dir], failing the test on a non-zero exit
void _git(String dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

/// Counts the line-count reads and answers each with a new count.
class _CountingGit extends GitService {
  _CountingGit() : super(const ProcessRunner());

  int reads = 0;

  @override
  Future<bool> isGitRepository(String path) async => true;

  @override
  Future<GitDiffStats> getFileDiffStats(String path, String filePath) async {
    reads++;
    return GitDiffStats(added: reads, removed: 0, isNewFile: false);
  }
}

void main() {
  late Directory repo;
  late ProviderContainer container;
  late String file;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('fide_git_repo_');
    _git(repo.path, ['init', '-q']);
    _git(repo.path, ['config', 'user.email', 'test@example.com']);
    _git(repo.path, ['config', 'user.name', 'Test']);
    file = path.join(repo.path, 'a.txt');
    File(file).writeAsStringSync('one\n');
    _git(repo.path, ['add', '.']);
    _git(repo.path, ['commit', '-q', '-m', 'init']);
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    repo.deleteSync(recursive: true);
  });

  /// The repository's state once loaded, kept alive by a listener.
  Future<GitRepoState> load() {
    final provider = gitRepoControllerProvider(repo.path);
    container.listen(provider, (_, _) {});
    return container.read(provider.future);
  }

  GitRepoController controller() =>
      container.read(gitRepoControllerProvider(repo.path).notifier);

  group('GitRepoController', () {
    test('loads changes, their line counts and recent commits', () async {
      File(file).writeAsStringSync('one\ntwo\n');

      final state = await load();

      expect(state.status.unstaged, ['a.txt']);
      expect(state.unstagedStats['a.txt']!.added, 1);
      expect(state.commits.map((c) => c.message), ['init']);
      expect(state.canAmend, isTrue);
      expect((state.ahead, state.behind), (0, 0));
    });

    test('stage and commit reload the state', () async {
      File(file).writeAsStringSync('two\n');
      await load();

      await controller().stage(['a.txt']);
      expect(
        container
            .read(gitRepoControllerProvider(repo.path))
            .value!
            .status
            .staged,
        ['a.txt'],
      );

      await controller().commit('second');
      final state = container.read(gitRepoControllerProvider(repo.path)).value!;
      expect(state.status.hasChanges, isFalse);
      expect(state.commits.first.message, 'second');
    });

    test('a failed action throws and still reloads', () async {
      await load();

      await expectLater(controller().push(), throwsA(isA<GitException>()));
      expect(
        container.read(gitRepoControllerProvider(repo.path)).hasValue,
        isTrue,
      );
    });

    test('reloads after a save', () async {
      await load();
      File(file).writeAsStringSync('changed\n');
      final reloaded = Completer<GitRepoState>();
      container.listen(gitRepoControllerProvider(repo.path), (_, next) {
        if (next.hasValue && !reloaded.isCompleted) {
          reloaded.complete(next.value);
        }
      });

      container.read(savedFilesRevisionProvider.notifier).state++;

      expect((await reloaded.future).status.unstaged, ['a.txt']);
    });

    test('fails without retrying outside a repository', () async {
      final outside = Directory.systemTemp.createTempSync('fide_no_git_');
      addTearDown(() => outside.deleteSync(recursive: true));
      final provider = gitRepoControllerProvider(outside.path);
      container.listen(provider, (_, _) {});

      await expectLater(
        container.read(provider.future),
        throwsA(isA<GitException>()),
      );
      expect(container.read(provider).isLoading, isFalse);
    });

    test('a commit refreshes the editor line counts', () async {
      File(file).writeAsStringSync('two\n');
      await load();
      final stats = gitDiffStatsProvider(file);
      container.listen(stats, (_, _) {});
      expect((await container.read(stats.future))!.hasChanges, isTrue);

      await controller().stage(['a.txt']);
      await controller().commit('second');

      expect((await container.read(stats.future))!.hasChanges, isFalse);
    });
  });

  group('gitDiffStatsProvider', () {
    test('reads the counts again after a save', () async {
      final git = _CountingGit();
      final counting = ProviderContainer(
        overrides: [gitServiceProvider.overrideWithValue(git)],
      );
      addTearDown(counting.dispose);
      final stats = gitDiffStatsProvider('/project/a.dart');
      counting.listen(stats, (_, _) {});

      expect((await counting.read(stats.future))!.added, 1);
      expect((await counting.read(stats.future))!.added, 1);

      counting.read(savedFilesRevisionProvider.notifier).state++;

      expect((await counting.read(stats.future))!.added, 2);
      expect(git.reads, 2);
    });

    test('is null for an empty path', () async {
      expect(await container.read(gitDiffStatsProvider('').future), isNull);
    });
  });
}
