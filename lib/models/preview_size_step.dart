/// The widths and heights a user can give a preview in the Preview panel:
/// whole steps of [step] logical pixels, from [step] to [max].
abstract final class PreviewSizeStep {
  /// The pixels between two lengths.
  static const double step = 10;

  /// The longest length.
  static const double max = 2000;

  /// [length] rounded to the nearest step, within [step] and [max].
  static double snap(double length) => _steps((length / step).round());

  /// The first step at or above [length], within [step] and [max], so a
  /// preview fixed at it shows all of its content.
  static double fit(double length) => _steps((length / step).ceil());

  /// [count] steps, within [step] and [max].
  static double _steps(int count) => (count * step).clamp(step, max);
}
