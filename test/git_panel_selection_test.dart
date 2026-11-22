import 'package:fide/panels/left/git_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/widgets/filename_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Changed files in the repository.
const int _fileCount = 40;

/// A repository with the changes [status] builds, by default
/// [_fileCount] changed files, and no remote, answered without running
/// git.
class _ChangedGit extends GitService {
  _ChangedGit({this.status = _changedFiles}) : super(const ProcessRunner());

  /// Builds the repository's status.
  final GitStatus Function() status;

  /// [_fileCount] files changed and not staged.
  static GitStatus _changedFiles() => GitStatus(
    staged: [],
    unstaged: [for (var i = 0; i < _fileCount; i++) 'file$i.dart'],
    untracked: [],
  );

  @override
  Future<GitStatus> getStatus(String path) async => status();

  @override
  Future<List<GitCommit>> getRecentCommits(
    String path, {
    int count = 0,
  }) async => [];

  @override
  Future<bool> canAmend(String path) async => false;

  @override
  Future<({int ahead, int behind})> syncCounts(String path) async =>
      (ahead: 0, behind: 0);

  @override
  Future<
    ({Map<String, GitDiffStats> staged, Map<String, GitDiffStats> unstaged})
  >
  getChangeStats(String projectPath, GitStatus status) async =>
      (staged: <String, GitDiffStats>{}, unstaged: <String, GitDiffStats>{});

  @override
  Future<bool> fetch(String path) async => false;
}

/// The Git panel of the repository at `/repo` that [git] answers for.
Widget _panel(GitService git) => ProviderScope(
  overrides: [gitServiceProvider.overrideWithValue(git)],
  child: const MaterialApp(
    home: Scaffold(body: GitPanel(projectPath: '/repo')),
  ),
);

void main() {
  testWidgets('a moved file is one row, with where it moved from', (
    tester,
  ) async {
    await tester.pumpWidget(
      _panel(
        _ChangedGit(
          status: () {
            final status = GitStatus(staged: [], unstaged: [], untracked: []);
            GitPorcelain.classify(' D', 'lib/widgets/home.dart', status);
            GitPorcelain.classify('??', 'lib/views/home.dart', status);
            return status
              ..addMove('lib/widgets/home.dart', 'lib/views/home.dart');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FileNameWidget), findsOneWidget);
    expect(find.text('Untracked'), findsNothing);
    expect(find.text('home.dart'), findsOneWidget);
    expect(find.text(' ← lib/widgets/home.dart'), findsOneWidget);
    expect(
      find.byTooltip('lib/views/home.dart\n\nMoved from lib/widgets/home.dart'),
      findsOneWidget,
    );
  });

  testWidgets('selecting a file rebuilds its row, not every changed file', (
    tester,
  ) async {
    await tester.pumpWidget(_panel(_ChangedGit()));
    await tester.pumpAndSettle();
    expect(find.byType(FileNameWidget), findsNWidgets(_fileCount));

    var rebuiltRows = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is FileNameWidget) rebuiltRows++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    await tester.tap(find.text('file1.dart'));
    await tester.pump();
    // The row selected
    expect(rebuiltRows, 1);

    rebuiltRows = 0;
    await tester.tap(find.text('file2.dart'));
    await tester.pump();
    // The row selected and the one it leaves
    expect(rebuiltRows, 2);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GitPanel)),
    );
    expect(container.read(selectedFileProvider)?.path, '/repo/file2.dart');
  });
}
