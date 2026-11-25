import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/spelling_finding.dart';
import 'package:fide/models/spelling_report.dart';
import 'package:fide/models/spelling_sort.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/spelling_analyzer.dart';
import 'package:fide/services/spelling_fixer.dart';
import 'package:fide/widget_services/file_location_row.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/blocking_task_dialog.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The project's [spelling] on the Status screen and the Info tab: its
/// score, the count of unknown words and the files they are in, a sort and
/// a filter, then each unknown word with Accept to list it as right in
/// `.fide-words` and a tap opening its first place to fix it there.
class SpellingCard extends ConsumerStatefulWidget {
  /// Creates the card showing [spelling].
  const SpellingCard(this.spelling, {super.key});

  /// The score and the words shown.
  final SpellingReport spelling;

  @override
  ConsumerState<SpellingCard> createState() => _SpellingCardState();
}

/// The Spelling card's state: the sort and the filter the user picked.
class _SpellingCardState extends ConsumerState<SpellingCard> {
  final TextEditingController _filter = TextEditingController();
  SpellingSort _sort = SpellingSort.mostUsed;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  /// Asks for the correct spelling of [word], [suggestion] given, and
  /// replaces every whole occurrence of it in the project's Dart files,
  /// the files written one at a time with Cancel checked before each.
  Future<void> _fix(String word, String? suggestion) async {
    final correct = await MessageBox.promptForText(
      context,
      title: 'Fix Word',
      labelText: 'Correct spelling',
      hintText: 'Correct spelling of $word',
      confirmLabel: 'Fix',
      initialText: suggestion ?? word,
    );
    final replacement = correct?.trim() ?? '';
    if (!mounted || replacement.isEmpty || replacement == word) return;
    final root = widget.spelling.rootPath;
    final written = await BlockingTaskDialog.run<List<String>>(
      context,
      title: 'Fix Word',
      step: 'Fixing "$word"…',
      run: (task) async {
        final changed = const SpellingFixer().plan(root, word, replacement);
        final done = <String>[];
        for (final entry in changed.entries) {
          if (task.isCancelled) break;
          task.report('Writing ${p.relative(entry.key, from: root)}…');
          File(entry.key).writeAsStringSync(entry.value);
          done.add(entry.key);
        }
        return done;
      },
    );
    if (written.isNotEmpty) {
      await ref.read(openDocumentsProvider.notifier).reloadWritten(written);
    }
    ref.invalidate(spellingProvider);
    if (!mounted) return;
    MessageBox.showSuccess(
      context,
      written.isEmpty
          ? 'Nothing was changed'
          : 'Fixed "$word" in ${written.length} files',
    );
  }

  @override
  Widget build(BuildContext context) {
    final spelling = widget.spelling;
    final query = _filter.text.trim().toLowerCase();
    final places = _placesByWord(
      spelling.findings,
      _sort,
    ).entries.where((entry) => entry.key.contains(query));
    final files = {for (final f in spelling.findings) f.path}.length;
    return SectionPanel(
      title: 'Spelling',
      count: spelling.misspelled.length,
      rightWidget: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.tiny,
        children: [
          BadgeStatus.score(spelling.score),
          ChoiceButtons<SpellingSort>(
            values: SpellingSort.values,
            selected: _sort,
            icon: (sort) => Icon(
              sort == SpellingSort.mostUsed
                  ? Icons.format_list_numbered
                  : Icons.sort_by_alpha,
            ),
            label: (sort) =>
                sort == SpellingSort.mostUsed ? 'Most Used' : 'A to Z',
            onSelected: (sort) => setState(() => _sort = sort),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.tiny,
        children: [
          Text(
            '${spelling.misspelled.length} unknown words in $files files, '
            '${spelling.findings.length} places, of ${spelling.distinctWords} '
            'distinct words checked. Tap a word to open its first place and '
            'fix it there; Accept lists a right word in .fide-words.',
            style: AppTextStyle.secondary(context),
          ),
          FilterField(controller: _filter, hintText: 'Filter words…'),
          for (final MapEntry(key: word, value: found) in places)
            Row(
              children: [
                Expanded(
                  child: FileLocationRow(
                    name: '$word (${found.length})',
                    path: found.first.path,
                    line: found.first.line,
                    rootPath: spelling.rootPath,
                    icon: Icons.spellcheck,
                  ),
                ),
                CompactIconButton(
                  icon: Icons.edit,
                  tooltip: 'Fix Word',
                  onPressed: () => _fix(word, found.first.suggestion),
                ),
                CompactIconButton(
                  icon: Icons.check,
                  tooltip: 'Accept Word',
                  onPressed: () {
                    SpellingAnalyzer.allow(spelling.rootPath, word);
                    ref.invalidate(spellingProvider);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// The places of each unknown word, in the [sort] order.
  static Map<String, List<SpellingFinding>> _placesByWord(
    List<SpellingFinding> findings,
    SpellingSort sort,
  ) {
    final byWord = <String, List<SpellingFinding>>{};
    for (final finding in findings) {
      byWord.putIfAbsent(finding.word, () => []).add(finding);
    }
    final entries = byWord.entries.toList()
      ..sort(
        (a, b) => sort == SpellingSort.alphabetical
            ? a.key.compareTo(b.key)
            : b.value.length.compareTo(a.value.length),
      );
    return Map.fromEntries(entries);
  }
}
