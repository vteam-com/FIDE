import 'dart:math' as math;
import 'dart:typed_data';

/// A decoded sound: the samples of each of its channels, from -1 to 1,
/// played at [sampleRate] frames a second.
class AudioClip {
  /// Creates a clip of [channels], all as long, played at [sampleRate].
  AudioClip({required this.sampleRate, required this.channels})
    : assert(channels.isNotEmpty, 'A clip has at least one channel');

  /// One list of samples per channel, each from -1 to 1.
  final List<Float32List> channels;

  /// Frames played a second.
  final int sampleRate;

  /// How long the clip plays.
  Duration get duration => Duration(
    microseconds: frameCount * Duration.microsecondsPerSecond ~/ sampleRate,
  );

  /// Samples in each channel.
  int get frameCount => channels.first.length;

  /// The loudest sample, from 0 to 1, of each of [count] equal slices of
  /// the clip, across its channels: the outline of its waveform.
  Float32List peaks(int count) {
    final peaks = Float32List(count);
    final frames = frameCount;
    if (frames == 0) return peaks;
    for (var slice = 0; slice < count; slice++) {
      final first = slice * frames ~/ count;
      final end = math.max(first + 1, (slice + 1) * frames ~/ count);
      var loudest = 0.0;
      for (final samples in channels) {
        for (var frame = first; frame < end && frame < frames; frame++) {
          loudest = math.max(loudest, samples[frame].abs());
        }
      }
      peaks[slice] = math.min(loudest, 1);
    }
    return peaks;
  }
}
