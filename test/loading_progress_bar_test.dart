import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/widgets/loading_progress_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress follows the furthest step and never exceeds 1', () {
    expect(LoadingProgressBar.progressOf([]), 0);
    expect(
      LoadingProgressBar.progressOf([
        LoadingAction(1, 'a', LoadingStatus.success),
        LoadingAction(
          AppMetric.loadingProgressSteps ~/ 2,
          'b',
          LoadingStatus.pending,
        ),
      ]),
      closeTo(0.5, 0.01),
    );
    expect(
      LoadingProgressBar.progressOf([
        LoadingAction(
          AppMetric.loadingProgressSteps + 1,
          'c',
          LoadingStatus.success,
        ),
      ]),
      1,
    );
  });
}
