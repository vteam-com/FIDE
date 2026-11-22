import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/panels/right/analyzer_findings_list.dart';
import 'package:fide/providers/analyzer_fix_controller.dart';
import 'package:fide/widget_services/file_location_row.dart';
import 'package:fide/widgets/action_card.dart';
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
/// place; Move All on a kind with several to move. A file that can't move
/// says why.
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
  /// parts, and Move, or why it can't move; disabled while a change is
  /// [running], showing it running when it is its own.
  @override
  Widget card(
    BuildContext context,
    WidgetRef ref,
    FileMove move, {
    required Object? running,
  }) {
    final blocker = move.blocker;
    return ActionCard(
      icon: _iconOf(move.category),
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
              busy: identical(running, move),
              onPressed: running != null
                  ? null
                  : () => _move(context, ref, [move]),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.small,
        children: [
          if (blocker != null)
            Text(blocker, style: AppTextStyle.secondary(context)),
          FileLocationRow(
            name: move.name,
            path: p.joinAll([projectPath, ...p.posix.split(move.path)]),
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
  /// [kind], with Move All when several of them can move; disabled while
  /// a change is [running], showing it running when it is its own.
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
        if (move.blocker == null) move,
    ];
    return SectionTitle(
      '${kind.label} (${findings.length})',
      action: movable.length < minMoveAll
          ? null
          : PrimaryButton(
              icon: AppIcon.fix,
              label: 'Move All',
              busy: running == kind,
              onPressed: running != null
                  ? null
                  : () => _move(context, ref, movable, key: kind),
            ),
    );
  }

  /// Moves the files of [moves], then tells how it went; [key] names the
  /// button that started it, the only move when null.
  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    List<FileMove> moves, {
    Object? key,
  }) async {
    final outcome = await ref
        .read(analyzerFixControllerProvider.notifier)
        .move(projectPath, moves, packageName: review.packageName, key: key);
    if (context.mounted) MessageBox.showOutcome(context, outcome);
  }

  /// The glyph of files of [category].
  static IconData _iconOf(CodeCategory category) => switch (category) {
    CodeCategory.views => Icons.web_asset,
    CodeCategory.models => Icons.data_object,
    _ => Icons.widgets_outlined,
  };
}
