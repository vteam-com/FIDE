import 'package:fide/panels/left/git_panel.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/commit_message_writer.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A model whose replies only end when cancelled, as a slow local model
/// the user stops.
class _StoppableModel implements ChatModel {
  @override
  Future<String> generate(
    String prompt,
    Duration timeout, {
    bool think = false,
    AiCancelToken? cancel,
  }) async {
    await cancel!.whenCancelled;
    throw const AiCancelledException();
  }

  @override
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    bool think = false,
    AiCancelToken? cancel,
  }) => throw UnimplementedError();
}

/// A repository with one staged file and no remote, answered without
/// running git.
class _StagedGit extends GitService {
  _StagedGit() : super(const ProcessRunner());

  @override
  Future<GitStatus> getStatus(String path) async =>
      GitStatus(staged: ['a.txt'], unstaged: [], untracked: []);

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

  @override
  Future<String> getStagedDiff(String path) async => 'diff';
}

void main() {
  testWidgets('the AI commit message shows a spinning Stop, which stops it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gitServiceProvider.overrideWithValue(_StagedGit()),
          commitMessageWriterProvider.overrideWithValue(
            CommitMessageWriter(_StoppableModel()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GitPanel(projectPath: '/repo')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final aiButton = find.byTooltip('Write commit message with AI');

    await tester.tap(aiButton);
    await tester.pump();
    final stop = find.byTooltip('Stop (Esc)');
    expect(stop, findsOneWidget);
    expect(aiButton, findsNothing);
    // One ring, around Stop: the task's only progress indicator
    expect(
      find.descendant(
        of: find.byType(TaskButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(stop, findsNothing);
    expect(aiButton, findsOneWidget);
  });
}
