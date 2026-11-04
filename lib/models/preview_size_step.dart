/// The widths and heights a user can give a preview in the Preview panel:
/// whole steps of [step] logical pixels, from [step] to [max].
abstract final class PreviewSizeStep {
  /// The pixels between two lengths.
  static const double step = 10;

  /// The longest length.
  static const double max = 2000;

  /// [length] rounded to the nearest step, within [step] and [max].
  static double snap(double length) =>
      ((length / step).round() * step).clamp(step, max);

  /// The first step at or above [length], within [step] and [max], so a
  /// preview fixed at it shows all of its content.
  static double fit(double length) =>
      ((length / step).ceil() * step).clamp(step, max);
}
