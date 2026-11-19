part of 'color_contrast_report.dart';

/// One color the code writes, with every name it is written as and how
/// many times: `Colors.grey` and `Color(0xFF9E9E9E)` are one color.
class ColorUsage {
  /// Creates the color of [colors] written as [names].
  const ColorUsage({required this.colors, required this.names});

  /// Its color in each theme the app renders, as the report's schemes
  /// order them; one when it is the same in every theme.
  final List<WcagColor> colors;

  /// How the code writes the color, such as `Colors.grey` or
  /// `colorScheme.primary`, each with how many times, the most first.
  final Map<String, int> names;

  /// How many times the code writes the color.
  int get count => names.values.fold(0, (sum, uses) => sum + uses);
}
