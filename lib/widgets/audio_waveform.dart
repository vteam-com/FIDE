import 'dart:math' as math;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/audio_edit.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

part 'audio_waveform.painter.dart';

/// A sound's waveform, the part a trim keeps between two handles and the
/// rest dimmed, with a playhead while it plays. Dragging moves the handle
/// nearest to where the drag starts.
class AudioWaveform extends StatefulWidget {
  /// Creates the waveform outlined by [peaks], kept from [start] to [end].
  const AudioWaveform({
    super.key,
    required this.peaks,
    required this.start,
    required this.end,
    required this.playhead,
    required this.onTrimmed,
  });

  /// Share of the sound, from 0 to 1, after the part kept.
  final double end;

  /// Called with the new start and end shares while a handle is dragged.
  final void Function(double start, double end) onTrimmed;

  /// The loudest sample, from 0 to 1, of each equal slice of the sound.
  final Float32List peaks;

  /// Share of the sound playing, or null when it isn't; the playhead moves
  /// with it without rebuilding the waveform.
  final ValueListenable<double?> playhead;

  /// Share of the sound, from 0 to 1, where the part kept starts.
  final double start;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> {
  /// Whether the drag under way moves the start handle rather than the
  /// end one.
  bool _movesStart = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, constraints) {
        double shareAt(Offset position) =>
            (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
        return MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              final share = shareAt(details.localPosition);
              _movesStart =
                  (share - widget.start).abs() < (share - widget.end).abs();
              _move(share);
            },
            onHorizontalDragUpdate: (details) =>
                _move(shareAt(details.localPosition)),
            // The playhead's steps repaint it alone, on top of the
            // waveform's own layer
            child: RepaintBoundary(
              child: CustomPaint(
                foregroundPainter: _AudioPlayheadPainter(
                  playhead: widget.playhead,
                  color: colors.onSurface,
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: constraints.biggest,
                    painter: _AudioWaveformPainter(
                      peaks: widget.peaks,
                      start: widget.start,
                      end: widget.end,
                      keptColor: colors.primary,
                      trimmedColor: colors.onSurface.withValues(
                        alpha: AppOpacity.faint,
                      ),
                      shadeColor: colors.onSurface.withValues(
                        alpha: AppOpacity.subtle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Moves the dragged handle to [share].
  void _move(double share) {
    const gap = AudioEdit.minKeptShare;
    if (_movesStart) {
      widget.onTrimmed(math.min(share, widget.end - gap), widget.end);
    } else {
      widget.onTrimmed(widget.start, math.max(share, widget.start + gap));
    }
  }
}
