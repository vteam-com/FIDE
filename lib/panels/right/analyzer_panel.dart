import 'package:fide/models/analyzer_review.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/panels/right/file_layout_list.dart';
import 'package:fide/panels/right/repeated_settings_list.dart';
import 'package:fide/providers/analyzer_review_notifier.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/dry_review_provider.dart';
import 'package:fide/providers/file_layout_review_provider.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_header.dart';
import 'package:fide/widgets/project_analysis_view.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Analyzer tab: one of the open project's refactoring reviews,
/// picked in its header, each with the deterministic changes code can
/// make: the File Layout, the files outside the folder their kind belongs
/// in, moved there with Move; the Repeated Widget Settings, the widget
/// settings it writes more than once, removed with Fix.
class AnalyzerPanel extends ConsumerStatefulWidget {
  /// Creates the reviews of the open project.
  const AnalyzerPanel({super.key});

  @override
  ConsumerState<AnalyzerPanel> createState() => _AnalyzerPanelState();
}

class _AnalyzerPanelState extends ConsumerState<AnalyzerPanel> {
  @override
  void initState() {
    super.initState();
    ref.read(analyzerReviewProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final projectPath = ref.watch(currentProjectPathProvider);
    if (projectPath == null) return const NoProjectPlaceholder();
    return switch (ref.watch(analyzerReviewProvider)) {
      AnalyzerReview.layout => _review<FileLayoutReview>(
        AnalyzerReview.layout,
        fileLayoutReviewProvider,
        subtitle: (review) =>
            '${review.moves.length.count('file')} to move, of '
            '${review.fileCount}',
        loadingMessage: 'Placing the files of lib…',
        builder: (review) =>
            FileLayoutList(projectPath: projectPath, review: review),
      ),
      AnalyzerReview.repeated => _review<DryReview>(
        AnalyzerReview.repeated,
        dryReviewProvider,
        subtitle: (review) =>
            '${review.findings.length.count('finding')} in '
            '${review.fileCount.count('file')}',
        loadingMessage: 'Comparing the widgets of lib…',
        builder: (review) =>
            RepeatedSettingsList(projectPath: projectPath, review: review),
      ),
    };
  }

  /// The tab showing [shown], its review read from [provider]: its name
  /// and [subtitle] atop, with the reviews to pick from and Refresh, then
  /// what [builder] makes of it, or [loadingMessage] before the first
  /// result, the tab's ring showing it running.
  Widget _review<T extends Object>(
    AnalyzerReview shown,
    FutureProvider<T?> provider, {
    required String Function(T review) subtitle,
    required String loadingMessage,
    required Widget Function(T review) builder,
  }) {
    final analysis = ref.watch(provider);
    final review = analysis.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          title: shown.label,
          subtitle: review == null ? null : subtitle(review),
          actions: [
            ChoiceButtons<AnalyzerReview>(
              values: AnalyzerReview.values,
              selected: shown,
              icon: (choice) => Icon(choice.icon),
              label: (choice) => choice.label,
              onSelected: ref.read(analyzerReviewProvider.notifier).select,
            ),
            // The Analyzer tab's ring shows the review running
            RefreshButton(
              onPressed: analysis.isLoading
                  ? null
                  : () => ref.invalidate(provider),
            ),
          ],
        ),
        Expanded(
          child: ProjectAnalysisView<T?>(
            analysis: analysis,
            loadingMessage: loadingMessage,
            // The Analyzer tab rings meanwhile
            isRinged: true,
            builder: (review) =>
                review == null ? const SizedBox.shrink() : builder(review),
          ),
        ),
      ],
    );
  }
}
