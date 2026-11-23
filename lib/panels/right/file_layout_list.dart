import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/panels/right/analyzer_findings_list.dart';
import 'package:fide/providers/analyzer_fix_controller.dart';
import 'package:fide/widget_services/file_location_row.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/blocking_task_dialog.dart';
import 'package:fide/widgets/code_category_icon.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The File Layout review of the project at [projectPath]: for each kind
/// of file (views, widgets, models) which folder it belongs in, then each
/// file outside it, a click away in the editor, with Move, which moves it
/// there with its parts and points every import naming it at its new
/// place; Move All on a kind with several to move. No move adds a
/// Layers issue, as fCheck judges the project's dependencies: a move
/// takes along the files that would otherwise add one, and says which it
/// fixes; a file that can't move says why.
class FileLayoutList extends AnalyzerFindingsList<CodeCategory, FileMove> {
  /// Creates the list of [review]'s moves.
  const FileLayoutList({
    super.key,
    required super.projectPath,
    required this.review,
  });

  /// Fewest files a kind has to move for its section to offer Move All.
  static const int minMoveAll = 2;

  /// The review shown.
  final FileLayoutReview review;

  /// [move]'s card: the file, the folder it moves from and to, with its
  /// parts, the files moved along and the Layers issues it fixes, and
  /// Move, or
  /// why it can't move; disabled while a change is [running].
  @override
  Widget card(
    BuildContext context,
    WidgetRef ref,
    FileMove move, {
    required Object? running,
  }) {
    final blocker =
        move.blocker ??
        switch (move.addedIssue) {
          final issue? => 'Moving it would add a Layers issue: $issue',
          null => null,
        };
    final along = move.along;
    return ActionCard(
      icon: move.category.icon,
      title: p.posix.basename(move.path),
      description:
          'From ${p.posix.dirname(move.path)} to '
          '${p.posix.dirname(move.target)}'
          '${move.parts.isEmpty ? '' : ', with ${move.parts.length.count('part')}'}',
      action: blocker != null
          ? null
          : PrimaryButton(
              icon: AppIcon.fix,
              label: 'Move',
              onPressed: running != null
                  ? null
                  : () => _move(
                      context,
                      ref,
                      move.planned,
                      key: move,
                      title: 'Move',
                    ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.small,
        children: [
          if (blocker != null)
            Text(blocker, style: AppTextStyle.secondary(context)),
          if (along.isNotEmpty)
            Text(
              'Moves along, so no Layers issue is added: '
              '${along.map((each) => p.posix.basename(each.path)).join(', ')}',
              style: AppTextStyle.secondary(context),
            ),
          for (final issue in move.fixedIssues)
            Text(
              'Fixes a Layers issue: $issue',
              style: AppTextStyle.secondary(context),
            ),
          FileLocationRow(
            name: move.name,
            path: ProjectPaths(projectPath).absoluteOf(move.path),
            line: move.line,
            rootPath: projectPath,
          ),
        ],
      ),
    );
  }

  @override
  String describe(CodeCategory kind) => FileLayoutReview.describe(kind);

  @override
  String get emptyMessage => 'Every file is in its folder';

  @override
  List<FileMove> findingsOf(CodeCategory kind) => review.of(kind);

  @override
  List<CodeCategory> get kinds => FileLayoutReview.categories;

  /// The title of the section of [findings], the moves of files of
  /// [kind], with Move All when several of them can move, which moves as
  /// many of them together as add no Layers issue, with the files they
  /// need along; disabled while a change is [running].
  @override
  Widget sectionTitle(
    BuildContext context,
    WidgetRef ref,
    CodeCategory kind,
    List<FileMove> findings, {
    required Object? running,
  }) {
    final movable = [
      for (final move in findings)
        if (move.canMove) move,
    ];
    return SectionTitle(
      '${kind.label} (${findings.length})',
      action: movable.length < minMoveAll
          ? null
          : PrimaryButton(
              icon: AppIcon.fix,
              label: 'Move All',
              onPressed: running != null
                  ? null
                  : () => _move(
                      context,
                      ref,
                      review.allPlanOf(kind).moves,
                      key: kind,
                      title: 'Move All',
                    ),
            ),
    );
  }

  /// Moves the files of [moves], the app blocked meanwhile by a dialog
  /// titled [title], the button's label, then tells how it went; [key]
  /// names the button that started it.
  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    List<FileMove> moves, {
    required Object key,
    required String title,
  }) async {
    final outcome = await BlockingTaskDialog.run(
      context,
      title: title,
      step:
          'Moving ${moves.length.count('file')} and pointing every import '
          'at ${moves.length == 1 ? 'it' : 'them'}…',
      run: (task) => ref
          .read(analyzerFixControllerProvider.notifier)
          .move(
            projectPath,
            moves,
            packageName: review.packageName,
            key: key,
            task: task,
          ),
    );
    if (context.mounted) MessageBox.showOutcome(context, outcome);
  }
}
