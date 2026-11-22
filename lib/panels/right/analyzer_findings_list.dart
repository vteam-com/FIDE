import 'package:fide/constants/constants.dart';
import 'package:fide/providers/analyzer_fix_controller.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A review of the Analyzer tab for the project at [projectPath], listed
/// as a section per kind of finding that has any: its [sectionTitle],
/// what the kind is about, then each finding's [card]; [emptyMessage]
/// when there are none.
///
/// Its changes run through [analyzerFixControllerProvider], one at a
/// time: the builders get the key of the one running, null while none
/// is, to disable their buttons and show it running on its own.
abstract class AnalyzerFindingsList<K, T> extends ConsumerWidget {
  /// Creates the list of a review of the project at [projectPath].
  const AnalyzerFindingsList({super.key, required this.projectPath});

  /// The open project's folder.
  final String projectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(analyzerFixControllerProvider);
    final sections = [
      for (final kind in kinds)
        if (findingsOf(kind) case final findings when findings.isNotEmpty)
          (kind, findings),
    ];
    if (sections.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        message: emptyMessage,
      );
    }
    return PanelScrollView(
      children: [
        for (final (kind, findings) in sections) ...[
          sectionTitle(context, ref, kind, findings, running: running),
          Text(describe(kind), style: AppTextStyle.secondary(context)),
          for (final finding in findings)
            card(context, ref, finding, running: running),
        ],
      ],
    );
  }

  /// The card of [finding], with its changes, disabled while one is
  /// [running].
  Widget card(
    BuildContext context,
    WidgetRef ref,
    T finding, {
    required Object? running,
  });

  /// What findings of [kind] are about.
  String describe(K kind);

  /// Shown when no kind has a finding.
  String get emptyMessage;

  /// The findings of [kind], in order.
  List<T> findingsOf(K kind);

  /// The kinds of findings, in display order.
  List<K> get kinds;

  /// The heading of the section of [findings] of [kind], a `SectionTitle`
  /// with the change applying to all of them, disabled while one is
  /// [running].
  Widget sectionTitle(
    BuildContext context,
    WidgetRef ref,
    K kind,
    List<T> findings, {
    required Object? running,
  });
}
