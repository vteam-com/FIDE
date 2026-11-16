import 'dart:typed_data';

import 'package:fide/models/audio_edit.dart';
import 'package:fide/services/audio_effects.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_test_support.dart';

void main() {
  group('AudioEffects', () {
    test('no edit keeps the clip as is', () {
      final clip = tone(seconds: 0.2);
      final edited = AudioEffects.apply(clip, AudioEdit.none);
      expect(edited.channels.first, clip.channels.first);
    });

    test('trims to the part kept', () {
      final clip = tone(seconds: 1);
      final edited = AudioEffects.apply(
        clip,
        const AudioEdit(start: 0.25, end: 0.75),
      );
      expect(edited.frameCount, testSampleRate ~/ 2);
      expect(
        edited.channels.first.first,
        clip.channels.first[testSampleRate ~/ 4],
      );
    });

    test('speeds up and slows down without changing the pitch', () {
      final clip = tone(frequency: 200, seconds: 2, channels: 2);
      for (final tempo in [0.5, 1.5, 2.0]) {
        final edited = AudioEffects.apply(clip, AudioEdit(tempo: tempo));
        expect(edited.frameCount, closeTo(clip.frameCount / tempo, 2));
        expect(edited.channels, hasLength(2));
        expect(
          frequencyOf(edited.channels.first, testSampleRate),
          closeTo(200, 6),
          reason: 'tempo $tempo',
        );
      }
    });

    test('shifts the pitch without changing the length', () {
      final clip = tone(frequency: 200, seconds: 2);
      for (final (semitones, frequency) in [(12, 400.0), (-12, 100.0)]) {
        final edited = AudioEffects.apply(
          clip,
          AudioEdit(semitones: semitones),
        );
        expect(edited.frameCount, closeTo(clip.frameCount, 2));
        expect(
          frequencyOf(edited.channels.first, testSampleRate),
          closeTo(frequency, frequency * 0.03),
          reason: '$semitones semitones',
        );
      }
    });

    test('keeps the loudness steady through the overlapping frames', () {
      final edited = AudioEffects.apply(
        tone(amplitude: 0.5, seconds: 2),
        const AudioEdit(tempo: 0.75),
      );
      final samples = edited.channels.first;
      final middle = samples.sublist(
        samples.length ~/ 10,
        samples.length * 9 ~/ 10,
      );
      final loudest = middle.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
      expect(loudest, closeTo(0.5, 0.05));
    });

    test('resample reads faster or slower by linear interpolation', () {
      final ramp = Float32List.fromList([0, 1, 2, 3]);
      expect(AudioEffects.resample(ramp, 1), same(ramp));
      expect(AudioEffects.resample(ramp, 2), [0, 2]);
      expect(AudioEffects.resample(ramp, 0.5), [0, 0.5, 1, 1.5, 2, 2.5, 3, 3]);
    });

    test('stretch leaves empty channels be', () {
      final empty = [Float32List(0)];
      expect(AudioEffects.stretch(empty, 2, testSampleRate), same(empty));
    });
  });
}
