part of 'audio_waveform.dart';

/// Paints [AudioWaveform] without its playhead: one vertical line per
/// pixel column as tall as the loudest sample under it, the trimmed parts
/// shaded, and the trim handles; repaints only when the sound, the trim or
/// the colors change, never as the playhead moves.
class _AudioWaveformPainter extends CustomPainter {
  _AudioWaveformPainter({
    required this.peaks,
    required this.start,
    required this.end,
    required this.keptColor,
    required this.trimmedColor,
    required this.shadeColor,
  });

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
    final middle = height / _AudioPlayheadPainter._halves;
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
    _AudioPlayheadPainter.drawMarker(canvas, size, start, kept);
    _AudioPlayheadPainter.drawMarker(canvas, size, end, kept);
  }

  @override
  bool shouldRepaint(_AudioWaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.keptColor != keptColor ||
      oldDelegate.trimmedColor != trimmedColor ||
      oldDelegate.shadeColor != shadeColor;
}

/// Paints [AudioWaveform]'s playhead over the waveform, alone, so each
/// step of the playhead draws one marker instead of the whole waveform.
class _AudioPlayheadPainter extends CustomPainter {
  _AudioPlayheadPainter({required this.playhead, required Color color})
    : _paint = Paint()..color = color,
      super(repaint: playhead);

  /// Splits the height in half to center the waveform and the markers.
  static const int _halves = 2;

  /// Share of the sound playing, or null when it isn't.
  final ValueListenable<double?> playhead;

  /// Fill of the playhead, made once for every step.
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final playing = playhead.value;
    if (playing != null) drawMarker(canvas, size, playing, _paint);
  }

  @override
  bool shouldRepaint(_AudioPlayheadPainter oldDelegate) =>
      oldDelegate.playhead != playhead ||
      oldDelegate._paint.color != _paint.color;

  /// Draws a full-height marker at [share] of the width, with [paint].
  static void drawMarker(Canvas canvas, Size size, double share, Paint paint) {
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
