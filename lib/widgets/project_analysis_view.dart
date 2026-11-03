import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a view shows of [analysis], built from fCheck's analysis of the
/// open project: [builder]'s widget once analyzed, still showing the last
/// result while a save re-analyzes, a spinner before the first one, and
/// the error when the analysis failed.
class ProjectAnalysisView<T> extends StatelessWidget {
  /// Creates the view of [analysis].
  const ProjectAnalysisView({
    super.key,
    required this.analysis,
    required this.builder,
  });

  /// The analysis, or what the view derives from it.
  final AsyncValue<T> analysis;

  /// Builds the view of the analyzed value.
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    return analysis.when(
      skipLoadingOnReload: true,
      data: builder,
      loading: () =>
          const LoadingIndicator(message: 'Analyzing project with fCheck…'),
      error: (error, _) =>
          EmptyState.error(message: 'Could not analyze the project: $error'),
    );
  }
}
