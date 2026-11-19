import 'dart:async';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_diff_stats_provider.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter/foundation.dart';
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

/// Counts the repository reads and answers each with a new line count.
class _CountingGit extends GitService {
  _CountingGit() : super(const ProcessRunner());

  int locations = 0;
  int reads = 0;

  @override
  Future<GitRepoLocation?> repoLocation(String path) async {
    locations++;
    return GitRepoLocation(root: path, prefix: '');
  }

  @override
  Future<GitHeadChanges> headChanges(String root) async {
    reads++;
    return GitHeadChanges(
      stats: {
        'a.dart': GitDiffStats(added: reads, removed: 0, isNewFile: false),
      },
      untracked: const {},
    );
  }
}

/// Runs real processes and counts them, by their arguments.
class _CountingRunner extends ProcessRunner {
  final List<String> launched = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) {
    launched.add('$executable ${arguments.join(' ')}');
    return super.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    launched.add('$executable ${arguments.join(' ')}');
    return super.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      mode: mode,
    );
  }
}

/// Longer than a debounced reload takes to start and finish.
const _settle = Duration(seconds: 2);

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

    test('shows the network action running, one at a time', () async {
      await load();
      GitActivity? activity() =>
          container.read(gitRepoControllerProvider(repo.path)).value!.activity;

      final refreshing = controller().refresh();
      expect(activity(), GitActivity.refresh);
      // A push asked meanwhile, say from another button, doesn't start
      await controller().push();
      expect(activity(), GitActivity.refresh);

      await refreshing;
      expect(activity(), isNull);
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

    test('reloads asked for while one runs share the next one', () async {
      final runner = _CountingRunner();
      final counting = ProviderContainer(
        overrides: [processRunnerProvider.overrideWithValue(runner)],
      );
      addTearDown(counting.dispose);
      final provider = gitRepoControllerProvider(repo.path);
      counting.listen(provider, (_, _) {});
      await counting.read(provider.future);
      runner.launched.clear();

      final notifier = counting.read(provider.notifier);
      await Future.wait([for (var i = 0; i < 5; i++) notifier.reload()]);

      // The first reload, then one for the four asked for meanwhile
      expect(runner.launched.where((c) => c.startsWith('git status')), [
        for (var i = 0; i < 2; i++) startsWith('git status'),
      ]);
    });

    test(
      'a save, its tree update and the open tabs read Git a few times',
      () async {
        final runner = _CountingRunner();
        final counting = ProviderContainer(
          overrides: [processRunnerProvider.overrideWithValue(runner)],
        );
        addTearDown(counting.dispose);
        const openTabs = 10;
        final files = [
          for (var i = 0; i < openTabs; i++) path.join(repo.path, 'f$i.txt'),
        ];
        for (final tab in files) {
          File(tab).writeAsStringSync('line\n');
        }
        _git(repo.path, ['add', '.']);
        _git(repo.path, ['commit', '-q', '-m', 'tabs']);
        final controller = gitRepoControllerProvider(repo.path);
        counting.listen(controller, (_, _) {});
        await counting.read(controller.future);
        for (final tab in files) {
          counting.listen(gitDiffStatsProvider(tab), (_, _) {});
          await counting.read(gitDiffStatsProvider(tab).future);
        }
        runner.launched.clear();

        File(files.first).writeAsStringSync('line\nsaved\n');
        counting.read(savedFilesRevisionProvider.notifier).state++;
        await Future<void>.delayed(AppDuration.updateDebounce);
        counting.read(projectTreeRevisionProvider.notifier).state++;
        await Future<void>.delayed(_settle);

        // Before: 44 processes, 4 per tab and 8 per controller reload
        debugPrint('git processes for one save: ${runner.launched.length}');
        expect(runner.launched.length, lessThanOrEqualTo(10));
        expect(
          (await counting.read(gitDiffStatsProvider(files.first).future))!
              .added,
          1,
        );
        expect(counting.read(controller).value!.status.unstaged, [
          path.basename(files.first),
        ]);
      },
    );

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
    test('reads the counts again once saves pause', () async {
      final git = _CountingGit();
      final counting = ProviderContainer(
        overrides: [gitServiceProvider.overrideWithValue(git)],
      );
      addTearDown(counting.dispose);
      final stats = gitDiffStatsProvider('/project/a.dart');
      counting.listen(stats, (_, _) {});

      expect((await counting.read(stats.future))!.added, 1);
      expect((await counting.read(stats.future))!.added, 1);

      // A burst of saves reads the repository once
      counting.read(savedFilesRevisionProvider.notifier).state++;
      counting.read(savedFilesRevisionProvider.notifier).state++;
      await Future<void>.delayed(AppDuration.saveBurstPause * 2);

      expect((await counting.read(stats.future))!.added, 2);
      expect((git.reads, git.locations), (2, 1));
    });

    test('open files of a repository share one read of it', () async {
      final git = _CountingGit();
      final counting = ProviderContainer(
        overrides: [gitServiceProvider.overrideWithValue(git)],
      );
      addTearDown(counting.dispose);
      for (final name in ['a.dart', 'b.dart', 'c.dart']) {
        final stats = gitDiffStatsProvider('/project/$name');
        counting.listen(stats, (_, _) {});
        await counting.read(stats.future);
      }

      expect((git.reads, git.locations), (1, 1));
    });

    test('is null outside a repository', () async {
      final outside = Directory.systemTemp.createTempSync('fide_no_git_');
      addTearDown(() => outside.deleteSync(recursive: true));
      final outsideFile = path.join(outside.path, 'a.txt');
      File(outsideFile).writeAsStringSync('a\n');

      final stats = gitDiffStatsProvider(outsideFile);
      container.listen(stats, (_, _) {});

      expect(await container.read(stats.future), isNull);
    });

    test('is null for an empty path', () async {
      expect(await container.read(gitDiffStatsProvider('').future), isNull);
    });
  });

  group('GitMessages', () {
    test('words a failed status read and passes other errors through', () {
      expect(
        GitMessages.describeLoadError(
          const GitException('git status', 'not a repo'),
        ),
        'Failed to get Git status: not a repo',
      );
      expect(GitMessages.describeLoadError(StateError('x')), 'Bad state: x');
    });
  });
}
