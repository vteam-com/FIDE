import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fide/models/audio_clip.dart';
import 'package:fide/models/audio_edit.dart';

/// Applies an [AudioEdit] to an [AudioClip]: trims it, changes its speed
/// without changing its pitch, and shifts its pitch without changing its
/// speed. Pure and synchronous; run it with `Isolate.run` for long clips.
///
/// The speed changes by WSOLA (waveform similarity overlap-add): the clip
/// is cut into overlapping windowed frames laid back down closer together
/// or further apart, each shifted a little to line up with the frame
/// before it so the waveform stays continuous. The pitch shifts by
/// stretching the clip by the pitch ratio, then resampling it back to its
/// length.
class AudioEffects {
  /// Overlapping frames per window: each output sample is the sum of two.
  static const int _overlap = 2;

  /// How long each windowed frame lasts, in seconds.
  static const double _frameSeconds = 0.04;

  /// How far, in seconds, a frame may move to line up with the one before.
  static const double _searchSeconds = 0.01;

  /// Samples skipped between those compared when lining frames up, to
  /// trade a little accuracy for speed.
  static const int _correlationStride = 4;

  const AudioEffects._();

  /// [clip] changed by [edit].
  static AudioClip apply(AudioClip clip, AudioEdit edit) {
    final frames = clip.frameCount;
    final first = (edit.start * frames).round().clamp(0, frames);
    final end = (edit.end * frames).round().clamp(first, frames);
    final trimmed = [
      for (final samples in clip.channels) samples.sublist(first, end),
    ];
    final ratio = edit.pitchRatio;
    final stretched = stretch(trimmed, ratio / edit.tempo, clip.sampleRate);
    return AudioClip(
      sampleRate: clip.sampleRate,
      channels: [for (final samples in stretched) resample(samples, ratio)],
    );
  }

  /// [samples] read [ratio] times as fast, by linear interpolation: shorter
  /// and higher when [ratio] is above 1, longer and lower below it.
  static Float32List resample(Float32List samples, double ratio) {
    if (ratio == 1) return samples;
    final output = Float32List((samples.length / ratio).floor());
    final last = samples.length - 1;
    for (var index = 0; index < output.length; index++) {
      final position = index * ratio;
      final before = position.floor().clamp(0, last);
      final after = math.min(before + 1, last);
      final weight = position - before;
      output[index] = samples[before] * (1 - weight) + samples[after] * weight;
    }
    return output;
  }

  /// [channels] made [factor] times as long, at the same pitch; the frames
  /// line up on the channels' mix so they stay in phase.
  static List<Float32List> stretch(
    List<Float32List> channels,
    double factor,
    int sampleRate,
  ) {
    if (factor == 1 || channels.first.isEmpty) return channels;
    final hop = (sampleRate * _frameSeconds).round() ~/ _overlap;
    final frame = hop * _overlap;
    final search = (sampleRate * _searchSeconds).round();
    final analysisHop = hop / factor;
    final length = channels.first.length;
    // Silence before the clip, so the first frame's fade in falls before
    // its start and is dropped
    final lead = analysisHop.ceil();
    final padded = lead + length + analysisHop.ceil() + frame + search;
    final inputs = [
      for (final samples in channels)
        Float32List(padded)..setAll(lead, samples),
    ];
    final mix = Float32List(padded);
    for (final input in inputs) {
      for (var index = 0; index < padded; index++) {
        mix[index] += input[index];
      }
    }
    final window = _hann(frame);
    final frameCount = ((lead + length) / analysisHop).ceil() + 1;
    final outputs = [
      for (final _ in channels) Float32List(frameCount * hop + frame),
    ];
    final lastPosition = padded - frame;
    var previous = 0;
    for (var index = 0; index < frameCount; index++) {
      final nominal = (index * analysisHop).round();
      final position = index == 0
          ? 0
          : _bestMatch(mix, previous + hop, nominal, search, hop, lastPosition);
      final at = index * hop;
      for (var channel = 0; channel < inputs.length; channel++) {
        final input = inputs[channel];
        final output = outputs[channel];
        for (var offset = 0; offset < frame; offset++) {
          output[at + offset] += input[position + offset] * window[offset];
        }
      }
      previous = position;
    }
    final skip = (lead * factor).round();
    final kept = (length * factor).round();
    return [for (final output in outputs) output.sublist(skip, skip + kept)];
  }

  /// The start, within [search] samples of [nominal] and at most [last],
  /// of the [overlap] samples of [mix] most like those at [target]: where
  /// the next frame continues the waveform of the one before.
  static int _bestMatch(
    Float32List mix,
    int target,
    int nominal,
    int search,
    int overlap,
    int last,
  ) {
    final from = (nominal - search).clamp(0, last);
    final to = (nominal + search).clamp(0, last);
    var best = from;
    var bestScore = double.negativeInfinity;
    for (var candidate = from; candidate <= to; candidate++) {
      var score = 0.0;
      for (var offset = 0; offset < overlap; offset += _correlationStride) {
        score += mix[target + offset] * mix[candidate + offset];
      }
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  /// A periodic Hann window [length] samples long; copies of it [length]
  /// / [_overlap] apart add up to exactly 1.
  static Float32List _hann(int length) {
    final window = Float32List(length);
    for (var index = 0; index < length; index++) {
      final sine = math.sin(math.pi * index / length);
      window[index] = sine * sine;
    }
    return window;
  }
}
