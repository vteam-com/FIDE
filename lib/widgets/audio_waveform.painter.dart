part of 'audio_waveform.dart';

/// Paints [AudioWaveform]: one vertical line per pixel column as tall as
/// the loudest sample under it, the trimmed parts shaded, the trim handles
/// and the playhead; repaints when the playhead moves.
class _AudioWaveformPainter extends CustomPainter {
  _AudioWaveformPainter({
    required this.peaks,
    required this.start,
    required this.end,
    required this.playhead,
    required this.keptColor,
    required this.trimmedColor,
    required this.shadeColor,
    required this.playheadColor,
  }) : super(repaint: playhead);

  /// Splits the height in half to center the waveform.
  static const int _halves = 2;

  /// Half-height of the line drawn for silence, so it still shows.
  static const double _minHalfHeight = 0.5;

  /// Offset of a pixel column's center from its left edge.
  static const double _pixelCenter = 0.5;

  /// Share of the sound after the part kept.
  final double end;

  /// Color of the waveform kept, and of the trim handles.
  final Color keptColor;

  /// The loudest sample of each equal slice of the sound.
  final Float32List peaks;

  /// Share of the sound playing, or null when it isn't.
  final ValueListenable<double?> playhead;

  /// Color of the playhead.
  final Color playheadColor;

  /// Color laid over the trimmed parts.
  final Color shadeColor;

  /// Share of the sound where the part kept starts.
  final double start;

  /// Color of the waveform trimmed off.
  final Color trimmedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final columns = width.floor();
    if (columns <= 0 || peaks.isEmpty) return;
    final middle = height / _halves;
    final kept = Paint()..color = keptColor;
    final trimmed = Paint()..color = trimmedColor;
    for (var column = 0; column < columns; column++) {
      final first = column * peaks.length ~/ columns;
      final last = math.max(first + 1, (column + 1) * peaks.length ~/ columns);
      var peak = 0.0;
      for (var slice = first; slice < last; slice++) {
        peak = math.max(peak, peaks[slice]);
      }
      final x = column + _pixelCenter;
      final share = x / columns;
      final half = math.max(peak * middle, _minHalfHeight);
      canvas.drawLine(
        Offset(x, middle - half),
        Offset(x, middle + half),
        share >= start && share <= end ? kept : trimmed,
      );
    }
    final shade = Paint()..color = shadeColor;
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, start * width, height), shade)
      ..drawRect(Rect.fromLTRB(end * width, 0, width, height), shade);
    _drawMarker(canvas, size, start, kept);
    _drawMarker(canvas, size, end, kept);
    final playing = playhead.value;
    if (playing != null) {
      _drawMarker(canvas, size, playing, Paint()..color = playheadColor);
    }
  }

  @override
  bool shouldRepaint(_AudioWaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.playhead != playhead ||
      oldDelegate.keptColor != keptColor ||
      oldDelegate.trimmedColor != trimmedColor ||
      oldDelegate.shadeColor != shadeColor ||
      oldDelegate.playheadColor != playheadColor;

  /// Draws a full-height marker at [share] of the width, with [paint].
  void _drawMarker(Canvas canvas, Size size, double share, Paint paint) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(share * size.width, size.height / _halves),
        width: AppSize.audioMarkerWidth,
        height: size.height,
      ),
      paint,
    );
  }
}
