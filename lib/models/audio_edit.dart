import 'dart:math' as math;

/// The changes the audio editor makes to a sound: the part of it kept, how
/// fast it plays and how its pitch shifts; `AudioEffects` applies them.
class AudioEdit {
  /// Creates an edit keeping the share of the sound from [start] to [end],
  /// played [tempo] times as fast and [semitones] higher.
  const AudioEdit({
    this.start = 0,
    this.end = 1,
    this.tempo = 1,
    this.semitones = 0,
  });

  /// The edit that changes nothing.
  static const AudioEdit none = AudioEdit();

  /// Least share of the sound a trim keeps.
  static const double minKeptShare = 0.01;

  /// Semitones in an octave, which doubles the pitch.
  static const int semitonesPerOctave = 12;

  /// How much an octave multiplies the pitch.
  static const double _octaveRatio = 2;

  /// Share of the sound, from 0 to 1, after the part kept.
  final double end;

  /// Semitones the pitch is shifted by; negative lowers it.
  final int semitones;

  /// Share of the sound, from 0 to 1, where the part kept starts.
  final double start;

  /// Speed of the sound: 2 plays it twice as fast, in half the time,
  /// without changing its pitch.
  final double tempo;

  @override
  int get hashCode => Object.hash(start, end, tempo, semitones);

  /// Whether the edit changes nothing.
  bool get isNone => this == none;

  /// How much the pitch shift multiplies each frequency.
  double get pitchRatio =>
      math.pow(_octaveRatio, semitones / semitonesPerOctave).toDouble();

  @override
  bool operator ==(Object other) =>
      other is AudioEdit &&
      other.start == start &&
      other.end == end &&
      other.tempo == tempo &&
      other.semitones == semitones;

  /// This edit with the given changes; [start] and [end] keep at least
  /// [minKeptShare] of the sound between them.
  AudioEdit copyWith({
    double? start,
    double? end,
    double? tempo,
    int? semitones,
  }) {
    final newStart = (start ?? this.start).clamp(0.0, 1 - minKeptShare);
    final newEnd = (end ?? this.end).clamp(newStart + minKeptShare, 1.0);
    return AudioEdit(
      start: newStart,
      end: newEnd,
      tempo: tempo ?? this.tempo,
      semitones: semitones ?? this.semitones,
    );
  }

  /// How long the edited sound plays, of a sound [source] long.
  Duration lengthOf(Duration source) => source * ((end - start) / tempo);

  /// The share of a [source] long sound playing [elapsed] into the edited
  /// sound, to place a playhead on the original's waveform.
  double sourceShareAt(Duration elapsed, Duration source) {
    if (source == Duration.zero) return start;
    final played = elapsed.inMicroseconds / source.inMicroseconds * tempo;
    return (start + played).clamp(start, end);
  }
}
