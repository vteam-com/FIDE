import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// What a view shows of [analysis], built from fCheck's analysis of the
/// open project: [builder]'s widget once analyzed, still showing the last
/// result while it re-analyzes (its `RefreshButton` spins), a
/// [LoadingIndicator] before the first one, and the error when the
/// analysis failed.
class ProjectAnalysisView<T> extends StatelessWidget {
  /// Creates the view of [analysis].
  const ProjectAnalysisView({
    super.key,
    required this.analysis,
    required this.builder,
    this.loadingMessage = 'Analyzing project with fCheck…',
  });

  /// The analysis, or what the view derives from it.
  final AsyncValue<T> analysis;

  /// Builds the view of the analyzed value.
  final Widget Function(T value) builder;

  /// Shown under the busy bar before the first result.
  final String loadingMessage;

  @override
  Widget build(BuildContext context) {
    return analysis.when(
      skipLoadingOnReload: true,
      data: builder,
      loading: () => LoadingIndicator(message: loadingMessage),
      error: (error, _) =>
          EmptyState.error(message: 'Could not analyze the project: $error'),
    );
  }
}
