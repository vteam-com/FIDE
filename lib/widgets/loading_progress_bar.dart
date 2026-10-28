import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
import 'package:flutter/material.dart';

/// Progress bar for a multi-step load, filled to the furthest step reached.
class LoadingProgressBar extends StatelessWidget {
  /// Creates a progress bar for [actions].
  const LoadingProgressBar({super.key, required this.actions});

  /// Steps reported so far.
  final List<LoadingAction> actions;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progressOf(actions),
      valueColor: AlwaysStoppedAnimation<Color>(
        Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// Fraction of `AppMetric.loadingProgressSteps` reached by [actions].
  static double progressOf(List<LoadingAction> actions) {
    if (actions.isEmpty) return 0;
    final currentStep = actions
        .map((action) => action.step)
        .reduce((a, b) => a > b ? a : b);
    return (currentStep / AppMetric.loadingProgressSteps).clamp(0.0, 1.0);
  }
}
