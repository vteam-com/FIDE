import 'package:fide/models/audio_clip.dart';
import 'package:fide/models/audio_edit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_test_support.dart';

void main() {
  group('AudioEdit', () {
    test('none changes nothing and equals its default', () {
      expect(AudioEdit.none.isNone, true);
      expect(const AudioEdit(), AudioEdit.none);
      expect(const AudioEdit().hashCode, AudioEdit.none.hashCode);
      expect(const AudioEdit(tempo: 1.5).isNone, false);
      expect(AudioEdit.none.pitchRatio, 1);
    });

    test('a pitch ratio doubles per octave', () {
      expect(const AudioEdit(semitones: 12).pitchRatio, closeTo(2, 1e-9));
      expect(const AudioEdit(semitones: -12).pitchRatio, closeTo(0.5, 1e-9));
    });

    test('copyWith keeps the trim in range and apart', () {
      final edit = AudioEdit.none.copyWith(start: -1, end: 2);
      expect(edit.start, 0);
      expect(edit.end, 1);
      final squeezed = AudioEdit.none.copyWith(start: 0.5, end: 0.5);
      expect(
        squeezed.end - squeezed.start,
        closeTo(AudioEdit.minKeptShare, 1e-9),
      );
      final kept = squeezed.copyWith(tempo: 2, semitones: 3);
      expect(kept.start, squeezed.start);
      expect(kept.tempo, 2);
      expect(kept.semitones, 3);
    });

    test('lengthOf shortens by the trim and the speed', () {
      const edit = AudioEdit(start: 0.25, end: 0.75, tempo: 2);
      expect(
        edit.lengthOf(const Duration(seconds: 4)),
        const Duration(seconds: 1),
      );
    });

    test('sourceShareAt maps the edited time onto the original', () {
      const edit = AudioEdit(start: 0.25, end: 0.75, tempo: 2);
      const source = Duration(seconds: 4);
      expect(edit.sourceShareAt(Duration.zero, source), 0.25);
      expect(
        edit.sourceShareAt(const Duration(milliseconds: 500), source),
        0.5,
      );
      expect(edit.sourceShareAt(const Duration(seconds: 9), source), 0.75);
      expect(edit.sourceShareAt(Duration.zero, Duration.zero), 0.25);
    });
  });

  group('AudioClip', () {
    test('lasts its frames at its sample rate', () {
      expect(tone(seconds: 0.5).duration, const Duration(milliseconds: 500));
    });

    test('peaks outline the loudest sample of each slice', () {
      final clip = tone(seconds: 1, amplitude: 0.5);
      final peaks = clip.peaks(4);
      expect(peaks, hasLength(4));
      for (final peak in peaks) {
        expect(peak, closeTo(0.5, 0.01));
      }
      final empty = AudioClip(
        sampleRate: 8000,
        channels: [tone().channels.first.sublist(0, 0)],
      );
      expect(empty.peaks(3), [0, 0, 0]);
    });
  });
}
