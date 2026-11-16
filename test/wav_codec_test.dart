import 'dart:convert';
import 'dart:typed_data';

import 'package:fide/models/audio_clip.dart';
import 'package:fide/services/wav_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_test_support.dart';

/// A WAV file of one [bits]-bit sample per channel of [frames], in format
/// [format], with a `LIST` chunk before the samples.
Uint8List wav({
  required int format,
  required int bits,
  required int channels,
  required List<int> sampleBytes,
  bool extensible = false,
}) {
  final fmt = BytesBuilder();
  final fmtData = ByteData(extensible ? 40 : 16)
    ..setUint16(0, extensible ? 0xFFFE : format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, 8000, Endian.little)
    ..setUint32(8, 8000 * channels * bits ~/ 8, Endian.little)
    ..setUint16(12, channels * bits ~/ 8, Endian.little)
    ..setUint16(14, bits, Endian.little);
  if (extensible) fmtData.setUint16(24, format, Endian.little);
  fmt.add(fmtData.buffer.asUint8List());
  Uint8List chunk(String id, List<int> body) {
    final header = ByteData(8)..setUint32(4, body.length, Endian.little);
    final bytes = header.buffer.asUint8List()..setAll(0, ascii.encode(id));
    return Uint8List.fromList([...bytes, ...body, if (body.length.isOdd) 0]);
  }

  final body = [
    ...ascii.encode('WAVE'),
    ...chunk('fmt ', fmt.toBytes()),
    ...chunk('LIST', [1, 2, 3]),
    ...chunk('data', sampleBytes),
  ];
  final riff = ByteData(8)..setUint32(4, body.length, Endian.little);
  return Uint8List.fromList([
    ...ascii.encode('RIFF'),
    ...riff.buffer.asUint8List(4),
    ...body,
  ]);
}

void main() {
  group('WavCodec', () {
    test('encodes a clip that decodes back within 16-bit precision', () {
      final clip = tone(channels: 2, seconds: 0.1);
      final decoded = WavCodec.decode(WavCodec.encode(clip));
      expect(decoded.sampleRate, clip.sampleRate);
      expect(decoded.channels, hasLength(2));
      expect(decoded.frameCount, clip.frameCount);
      for (var frame = 0; frame < clip.frameCount; frame++) {
        expect(
          decoded.channels[1][frame],
          closeTo(clip.channels[1][frame], 1 / 30000),
        );
      }
    });

    test('clamps samples beyond full scale', () {
      final clip = AudioClip(
        sampleRate: 8000,
        channels: [
          Float32List.fromList([2, -2]),
        ],
      );
      final decoded = WavCodec.decode(WavCodec.encode(clip));
      expect(decoded.channels.first[0], closeTo(1, 1e-4));
      expect(decoded.channels.first[1], closeTo(-1, 1e-4));
    });

    test('reads 8, 24 and 32-bit integer samples past other chunks', () {
      final eight = WavCodec.decode(
        wav(format: 1, bits: 8, channels: 1, sampleBytes: [0, 128, 255]),
      );
      expect(eight.channels.first, [-1, 0, closeTo(127 / 128, 1e-6)]);

      final twentyFour = WavCodec.decode(
        wav(
          format: 1,
          bits: 24,
          channels: 1,
          sampleBytes: [0x00, 0x00, 0xC0, 0x00, 0x00, 0x40],
        ),
      );
      expect(twentyFour.channels.first, [-0.5, 0.5]);

      final thirtyTwo = WavCodec.decode(
        wav(
          format: 1,
          bits: 32,
          channels: 1,
          sampleBytes: [0x00, 0x00, 0x00, 0x40],
        ),
      );
      expect(thirtyTwo.channels.first, [0.5]);
    });

    test('reads float samples, also in an extensible header', () {
      final float32 = ByteData(4)..setFloat32(0, 0.25, Endian.little);
      final float64 = ByteData(8)..setFloat64(0, -0.75, Endian.little);
      expect(
        WavCodec.decode(
          wav(
            format: 3,
            bits: 32,
            channels: 1,
            sampleBytes: float32.buffer.asUint8List(),
          ),
        ).channels.first,
        [0.25],
      );
      expect(
        WavCodec.decode(
          wav(
            format: 3,
            bits: 64,
            channels: 1,
            sampleBytes: float64.buffer.asUint8List(),
            extensible: true,
          ),
        ).channels.first,
        [-0.75],
      );
    });

    test('rejects files that are not WAV or of unread formats', () {
      expect(
        () => WavCodec.decode(Uint8List.fromList(ascii.encode('ID3 mp3'))),
        throwsFormatException,
      );
      expect(
        () => WavCodec.decode(
          wav(format: 2, bits: 4, channels: 1, sampleBytes: [0]),
        ),
        throwsFormatException,
      );
      expect(
        () => WavCodec.decode(
          wav(format: 1, bits: 12, channels: 1, sampleBytes: [0, 0]),
        ),
        throwsFormatException,
      );
      expect(
        () => WavCodec.decode(
          wav(format: 3, bits: 16, channels: 1, sampleBytes: [0, 0]),
        ),
        throwsFormatException,
      );
      final noData = Uint8List.fromList([
        ...ascii.encode('RIFF'),
        0,
        0,
        0,
        0,
        ...ascii.encode('WAVE'),
      ]);
      expect(() => WavCodec.decode(noData), throwsFormatException);
    });
  });
}
