import 'package:fide/models/health_check.dart';

/// What one [HealthCheck] found and what it costs the quality score; the
/// score, its breakdown and the health card all read the same list.
class HealthDeduction {
  /// Which check this is.
  final HealthCheck check;

  /// The rule, e.g. `Build errors (max 50 points)`.
  final String label;

  /// Occurrences found (1 for a missing lock file); 0 when all is well.
  final int count;

  /// Points subtracted from the score; 0 when the check costs nothing.
  final int points;

  /// Creates a deduction.
  const HealthDeduction({
    required this.check,
    required this.label,
    required this.count,
    required this.points,
  });

  /// Whether the check costs points.
  bool get isActive => points > 0;
}
