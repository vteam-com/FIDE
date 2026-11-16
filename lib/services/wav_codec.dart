import 'dart:convert';
import 'dart:typed_data';

import 'package:fide/models/audio_clip.dart';

/// Reads and writes WAV files, the format the audio editor works in.
///
/// Reads integer PCM of 8, 16, 24 or 32 bits and 32 or 64-bit float,
/// plain or in a `WAVE_FORMAT_EXTENSIBLE` header; writes 16-bit PCM, which
/// every player and converter accepts.
class WavCodec {
  /// Bits in a byte.
  static const int _bitsPerByte = 8;

  /// Bytes of a chunk's id and of its size field.
  static const int _chunkFieldSize = 4;

  /// Bytes of a chunk's header: its id then its size.
  static const int _chunkHeaderSize = _chunkFieldSize * 2;

  /// Id of the chunk holding the samples.
  static const String _dataId = 'data';

  /// Bits per sample [encode] writes.
  static const int _encodedBits = 16;

  /// Offset in the `fmt ` chunk of the sub-format of an extensible header.
  static const int _extensibleFormatOffset = 24;

  /// Format code of an extensible header, whose real code is its
  /// sub-format.
  static const int _extensibleFormat = 0xFFFE;

  /// Format code of IEEE float samples.
  static const int _floatFormat = 3;

  /// Offsets of the `fmt ` chunk's fields.
  static const int _fmtBitsOffset = 14;
  static const int _fmtBlockAlignOffset = 12;
  static const int _fmtByteRateOffset = 8;
  static const int _fmtChannelsOffset = 2;
  static const int _fmtSampleRateOffset = 4;

  /// Id of the chunk describing the samples.
  static const String _fmtId = 'fmt ';

  /// Bytes of a plain PCM `fmt ` chunk.
  static const int _fmtSize = 16;

  /// Bytes of the header [encode] writes: the RIFF header, then the
  /// `fmt ` chunk, then the `data` chunk's header.
  static const int _headerSize =
      _riffHeaderSize + _chunkHeaderSize + _fmtSize + _chunkHeaderSize;

  /// Format code of integer PCM samples.
  static const int _pcmFormat = 1;

  /// Bytes of the RIFF header: `RIFF`, the file size and `WAVE`.
  static const int _riffHeaderSize = 12;

  /// Id opening every WAV file.
  static const String _riffId = 'RIFF';

  /// Bit depths of the sample widths read, in bits.
  static const int _bits8 = 8;
  static const int _bits16 = 16;
  static const int _bits24 = 24;
  static const int _bits32 = 32;
  static const int _bits64 = 64;

  /// Middle of the unsigned 8-bit range, which is silence.
  static const int _unsigned8Offset = 128;

  /// Form type of a WAV file in its RIFF header.
  static const String _waveId = 'WAVE';

  const WavCodec._();

  /// The clip encoded in the WAV file [bytes].
  ///
  /// Throws a [FormatException] when [bytes] isn't a WAV file of a sample
  /// format this codec reads.
  static AudioClip decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < _riffHeaderSize ||
        _id(bytes, 0) != _riffId ||
        _id(bytes, _riffHeaderSize - _chunkFieldSize) != _waveId) {
      throw const FormatException('Not a WAV file');
    }
    ByteData? format;
    ByteData? samples;
    var offset = _riffHeaderSize;
    while (offset + _chunkHeaderSize <= bytes.length) {
      final id = _id(bytes, offset);
      final declared = data.getUint32(offset + _chunkFieldSize, Endian.little);
      final body = offset + _chunkHeaderSize;
      final size = declared.clamp(0, bytes.length - body);
      if (id == _fmtId) format = ByteData.sublistView(bytes, body, body + size);
      if (id == _dataId) {
        samples = ByteData.sublistView(bytes, body, body + size);
      }
      // Chunks are padded to an even size
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    if (format == null || samples == null || format.lengthInBytes < _fmtSize) {
      throw const FormatException('WAV file without format or samples');
    }
    return _decodeSamples(format, samples);
  }

  /// [clip] as a 16-bit PCM WAV file.
  static Uint8List encode(AudioClip clip) {
    final channelCount = clip.channels.length;
    final bytesPerSample = _encodedBits ~/ _bitsPerByte;
    final blockAlign = channelCount * bytesPerSample;
    final dataSize = clip.frameCount * blockAlign;
    final bytes = Uint8List(_headerSize + dataSize);
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    void writeId(String id) {
      bytes.setAll(offset, ascii.encode(id));
      offset += _chunkFieldSize;
    }

    void writeUint32(int value) {
      data.setUint32(offset, value, Endian.little);
      offset += _chunkFieldSize;
    }

    writeId(_riffId);
    writeUint32(bytes.length - _chunkHeaderSize);
    writeId(_waveId);
    writeId(_fmtId);
    writeUint32(_fmtSize);
    final fmt = offset;
    data
      ..setUint16(fmt, _pcmFormat, Endian.little)
      ..setUint16(fmt + _fmtChannelsOffset, channelCount, Endian.little)
      ..setUint32(fmt + _fmtSampleRateOffset, clip.sampleRate, Endian.little)
      ..setUint32(
        fmt + _fmtByteRateOffset,
        clip.sampleRate * blockAlign,
        Endian.little,
      )
      ..setUint16(fmt + _fmtBlockAlignOffset, blockAlign, Endian.little)
      ..setUint16(fmt + _fmtBitsOffset, _encodedBits, Endian.little);
    offset += _fmtSize;
    writeId(_dataId);
    writeUint32(dataSize);
    final full = _fullScale(_encodedBits) - 1;
    for (var frame = 0; frame < clip.frameCount; frame++) {
      for (final channel in clip.channels) {
        final sample = channel[frame].clamp(-1.0, 1.0);
        data.setInt16(offset, (sample * full).round(), Endian.little);
        offset += bytesPerSample;
      }
    }
    return bytes;
  }

  /// The clip of [samples], laid out as [format] describes.
  static AudioClip _decodeSamples(ByteData format, ByteData samples) {
    var code = format.getUint16(0, Endian.little);
    if (code == _extensibleFormat &&
        format.lengthInBytes >= _extensibleFormatOffset + _chunkFieldSize) {
      code = format.getUint16(_extensibleFormatOffset, Endian.little);
    }
    final channelCount = format.getUint16(_fmtChannelsOffset, Endian.little);
    final sampleRate = format.getUint32(_fmtSampleRateOffset, Endian.little);
    final bits = format.getUint16(_fmtBitsOffset, Endian.little);
    final blockAlign = format.getUint16(_fmtBlockAlignOffset, Endian.little);
    final read = _sampleReader(code, bits);
    if (read == null || channelCount == 0 || blockAlign == 0) {
      throw FormatException('Unsupported WAV format $code with $bits bits');
    }
    final bytesPerSample = bits ~/ _bitsPerByte;
    final frameCount = samples.lengthInBytes ~/ blockAlign;
    final channels = List.generate(
      channelCount,
      (_) => Float32List(frameCount),
    );
    for (var frame = 0; frame < frameCount; frame++) {
      for (var channel = 0; channel < channelCount; channel++) {
        final offset = frame * blockAlign + channel * bytesPerSample;
        channels[channel][frame] = read(samples, offset);
      }
    }
    return AudioClip(sampleRate: sampleRate, channels: channels);
  }

  /// The value of a full-scale sample of [bits] signed bits.
  static int _fullScale(int bits) => 1 << (bits - 1);

  /// The four-letter id at [offset] in [bytes].
  static String _id(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + _chunkFieldSize));

  /// Reads one sample, from -1 to 1, of format [code] and [bits] bits at an
  /// offset; null when the format isn't read.
  static double Function(ByteData, int)? _sampleReader(int code, int bits) {
    if (code == _floatFormat) {
      return switch (bits) {
        _bits32 => (data, offset) => data.getFloat32(offset, Endian.little),
        _bits64 => (data, offset) => data.getFloat64(offset, Endian.little),
        _ => null,
      };
    }
    if (code != _pcmFormat) return null;
    final full = _fullScale(bits);
    return switch (bits) {
      _bits8 => (
        data,
        offset,
      ) => (data.getUint8(offset) - _unsigned8Offset) / _unsigned8Offset,
      _bits16 => (data, offset) => data.getInt16(offset, Endian.little) / full,
      _bits24 => (data, offset) => _int24(data, offset) / full,
      _bits32 => (data, offset) => data.getInt32(offset, Endian.little) / full,
      _ => null,
    };
  }

  /// The signed little-endian 24-bit integer at [offset].
  static int _int24(ByteData data, int offset) {
    final low = data.getUint16(offset, Endian.little);
    final high = data.getInt8(offset + _bits16 ~/ _bitsPerByte);
    return high << _bits16 | low;
  }
}
