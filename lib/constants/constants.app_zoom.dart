part of 'constants.dart';

/// The zoom levels of the whole UI, stepped through by Zoom In and Zoom Out
/// as in browsers and VS Code.
class AppZoom {
  /// The zoom of an unscaled UI.
  static const double actualSize = 1;

  /// The levels Zoom In and Zoom Out step through, smallest first.
  static const List<double> levels = [
    0.5,
    0.67,
    0.75,
    0.8,
    0.9,
    actualSize,
    1.1,
    1.25,
    1.5,
    1.75,
    2,
  ];

  /// Factor the zoom buttons of a canvas, such as the architecture graph,
  /// zoom in or out by.
  static const double canvasStep = 1.25;

  /// Percent in one whole, to show a zoom such as `125%`.
  static const int _percent = 100;

  /// The next level above [zoom], or the largest level.
  static double larger(double zoom) =>
      levels.firstWhere((level) => level > zoom, orElse: () => levels.last);

  /// The next level below [zoom], or the smallest level.
  static double smaller(double zoom) =>
      levels.lastWhere((level) => level < zoom, orElse: () => levels.first);

  /// [zoom] as a whole percent, such as `125%`.
  static String label(double zoom) => '${(zoom * _percent).round()}%';

  const AppZoom._();
}
