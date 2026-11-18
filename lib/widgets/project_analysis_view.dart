import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// What a view shows of [analysis], built from fCheck's analysis of the
/// open project: [builder]'s widget once analyzed, still showing the last
/// result while it re-analyzes (its `RefreshButton` spins), a
/// [LoadingIndicator] before the first one (just its message when
/// [isRinged]), and the error when the analysis failed.
class ProjectAnalysisView<T> extends StatelessWidget {
  /// Creates the view of [analysis].
  const ProjectAnalysisView({
    super.key,
    required this.analysis,
    required this.builder,
    this.loadingMessage = 'Analyzing project with fCheck…',
    this.isRinged = false,
  });

  /// The analysis, or what the view derives from it.
  final AsyncValue<T> analysis;

  /// Builds the view of the analyzed value.
  final Widget Function(T value) builder;

  /// Whether a ring already shows the analysis running before the first
  /// result, such as the panel's tab or a `RefreshButton` in its header:
  /// the loading message then shows without the bar.
  final bool isRinged;

  /// Shown before the first result, under the busy bar unless
  /// [isRinged].
  final String loadingMessage;

  @override
  Widget build(BuildContext context) {
    return analysis.when(
      skipLoadingOnReload: true,
      data: builder,
      loading: () => isRinged
          ? EmptyState(message: loadingMessage)
          : LoadingIndicator(message: loadingMessage),
      error: (error, _) =>
          EmptyState.error(message: 'Could not analyze the project: $error'),
    );
  }
}
