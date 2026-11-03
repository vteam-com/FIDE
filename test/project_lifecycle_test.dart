import 'dart:io';

import 'package:fide/models/app_view_state.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/file_system_watcher.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/loading_progress.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every Git command as failed, so no folder is a repository.
class _NoGitRunner extends ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async => ProcessResult(0, 1, '', '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoadingProgress', () {
    late List<List<LoadingAction>> published;
    late LoadingProgress progress;

    setUp(() {
      published = [];
      progress = LoadingProgress(published.add, pace: Duration.zero);
    });

    List<(int, String, LoadingStatus)> log() => [
      for (final action in published.last)
        (action.step, action.text, action.status),
    ];

    test('numbers the steps and marks each by its result', () async {
      progress.start();
      expect(await progress.step('One', () => true), true);
      expect(await progress.step('Two', () async => false), false);

      expect(log(), [
        (1, 'One', LoadingStatus.success),
        (2, 'Two', LoadingStatus.failed),
      ]);
    });

    test('shows a running step as pending', () async {
      progress.start();
      await progress.step('One', () {
        expect(log(), [(1, 'One', LoadingStatus.pending)]);
        return true;
      });
    });

    test('fails a step that throws, then rethrows', () async {
      progress.start();
      await expectLater(
        progress.step('One', () => throw StateError('broken')),
        throwsStateError,
      );
      expect(log(), [(1, 'One', LoadingStatus.failed)]);
    });

    test('starts each job with an empty log', () async {
      progress.start();
      await progress.step('One', () => true);
      progress.start();
      expect(published.last, isEmpty);
    });
  });

  group('ProjectManager', () {
    late Directory projects;
    late ProviderContainer container;

    // What the folder picker answers; null cancels
    String? pickedFolder;

    setUp(() {
      projects = Directory.systemTemp.createTempSync('fide_lifecycle_');
      SharedPreferences.setMockInitialValues({});
      pickedFolder = null;
      container = ProviderContainer(
        overrides: [
          folderPickerProvider.overrideWithValue(() async => pickedFolder),
          projectTreeLoaderProvider.overrideWithValue(loadProjectTreeInline),
          fileSystemWatcherProvider.overrideWith(
            (_) => FileSystemWatcher(watchEnabled: false),
          ),
          gitServiceProvider.overrideWithValue(GitService(_NoGitRunner())),
          projectLoadProgressProvider.overrideWith(
            (ref) => LoadingProgress(
              (actions) =>
                  ref.read(loadingActionsProvider.notifier).state = actions,
              pace: Duration.zero,
            ),
          ),
        ],
      );
    });
    tearDown(() {
      container.dispose();
      projects.deleteSync(recursive: true);
    });

    /// Creates a Flutter project folder named [name].
    String flutterProject(String name) {
      final path = p.join(projects.path, name);
      Directory(p.join(path, 'lib')).createSync(recursive: true);
      File(p.join(path, 'lib', 'main.dart'))
          .writeAsStringSync('void main() {}');
      File(p.join(path, 'pubspec.yaml')).writeAsStringSync(
        'name: $name\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
      return path;
    }

    test('loads a project, logging its steps and remembering it', () async {
      final path = flutterProject('one');

      expect(
        await container.read(projectManagerProvider).loadProject(path),
        true,
      );

      expect(container.read(currentProjectPathProvider), path);
      expect(container.read(projectLoadedProvider), true);
      expect(container.read(projectLoadingProvider), false);
      expect(container.read(mruFoldersProvider), [path]);
      expect(
        container.read(loadingActionsProvider).map((a) => a.status),
        everyElement(LoadingStatus.success),
      );
    });

    test('unloads the open project and its documents first', () async {
      final one = flutterProject('one');
      final two = flutterProject('two');
      final manager = container.read(projectManagerProvider);
      await manager.loadProject(one);
      await container
          .read(openDocumentsProvider.notifier)
          .open(p.join(one, 'lib', 'main.dart'));

      await manager.loadProject(two);

      expect(container.read(currentProjectPathProvider), two);
      expect(container.read(openDocumentsProvider).documents, isEmpty);
    });

    test('fails on a folder that is no Flutter project', () async {
      final folder = Directory(p.join(projects.path, 'plain'))..createSync();

      expect(
        await container.read(projectManagerProvider).loadProject(folder.path),
        false,
      );

      expect(container.read(projectLoadedProvider), false);
      expect(container.read(mruFoldersProvider), isEmpty);
      expect(
        container.read(loadingActionsProvider).single.status,
        LoadingStatus.failed,
      );
    });

    test('the app view shows the loading steps, then the IDE', () async {
      final path = flutterProject('one');
      final view = container.read(appViewProvider.notifier);

      final loading = view.loadProject(path);
      expect(container.read(appViewProvider), AppViewState.loadingProject);
      expect(view.loadingProjectPath, path);

      expect(await loading, true);
      expect(container.read(appViewProvider), AppViewState.mainLayout);
      expect(view.loadingProjectPath, isNull);
    });

    test('the app view returns to welcome when a project fails', () async {
      final folder = Directory(p.join(projects.path, 'plain'))..createSync();
      final view = container.read(appViewProvider.notifier);

      expect(await view.loadProject(folder.path), false);

      expect(container.read(appViewProvider), AppViewState.welcome);
    });

    test('closing the project returns the app view to welcome', () async {
      final view = container.read(appViewProvider.notifier);
      await view.loadProject(flutterProject('one'));

      view.closeProject();

      expect(container.read(appViewProvider), AppViewState.welcome);
      expect(container.read(projectLoadedProvider), false);
    });

    test('the app view enters and leaves the new-project wizard', () async {
      final view = container.read(appViewProvider.notifier);
      await view.loadProject(flutterProject('one'));

      view.showCreateProject();
      expect(container.read(appViewProvider), AppViewState.createProject);
      expect(container.read(projectLoadedProvider), false);

      view.showWelcome();
      expect(container.read(appViewProvider), AppViewState.welcome);
    });

    test('the app view opens the folder picked, or reports why not', () async {
      final view = container.read(appViewProvider.notifier);

      await view.pickAndOpenProject();
      expect(container.read(appViewProvider), AppViewState.welcome);
      expect(container.read(projectOpenErrorProvider), isNull);

      pickedFolder = (Directory(
        p.join(projects.path, 'plain'),
      )..createSync()).path;
      await view.pickAndOpenProject();
      expect(
        container.read(projectOpenErrorProvider),
        AppViewNotifier.invalidProjectMessage,
      );

      pickedFolder = flutterProject('one');
      await view.pickAndOpenProject();
      expect(container.read(appViewProvider), AppViewState.mainLayout);
    });

    test('the app view reopens the most recent project', () async {
      final view = container.read(appViewProvider.notifier);
      await view.openRecentProject();
      expect(container.read(appViewProvider), AppViewState.welcome);

      final path = flutterProject('one');
      await container.read(mruFoldersProvider.notifier).touch(path);
      await view.openRecentProject();

      expect(container.read(appViewProvider), AppViewState.mainLayout);
      expect(container.read(currentProjectPathProvider), path);
    });
  });
}
