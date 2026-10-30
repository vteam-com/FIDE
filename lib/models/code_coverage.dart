import 'package:fide/constants/constants.dart';

/// Line coverage summed from an `lcov.info` report, as written by
/// `flutter test --coverage`.
class CodeCoverage {
  /// lcov record prefix counting instrumented lines.
  static const String _linesFoundPrefix = 'LF:';

  /// lcov record prefix counting executed lines.
  static const String _linesHitPrefix = 'LH:';

  /// Instrumented lines across every source file.
  final int linesFound;

  /// Lines the tests executed.
  final int linesHit;

  /// Creates coverage from line totals.
  const CodeCoverage({required this.linesFound, required this.linesHit});

  /// Sums the `LF`/`LH` records of every source file in lcov [content].
  factory CodeCoverage.fromLcov(String content) {
    var found = 0;
    var hit = 0;
    for (final line in content.split('\n')) {
      if (line.startsWith(_linesFoundPrefix)) {
        found += int.tryParse(line.substring(_linesFoundPrefix.length)) ?? 0;
      } else if (line.startsWith(_linesHitPrefix)) {
        hit += int.tryParse(line.substring(_linesHitPrefix.length)) ?? 0;
      }
    }
    return CodeCoverage(linesFound: found, linesHit: hit);
  }

  /// Share of instrumented lines executed, from 0 to [AppMetric.maxScore].
  int get percent => linesFound == 0
      ? 0
      : (linesHit * AppMetric.maxScore / linesFound).round();
}
