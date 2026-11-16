import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fide/models/audio_clip.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/wav_codec.dart';
import 'package:path/path.dart' as p;

/// A sound loaded for the audio editor: its [clip] and the outline of its
/// waveform, the loudest sample of each of a number of equal slices.
typedef LoadedAudio = ({AudioClip clip, Float32List peaks});

/// Loads sound files into [AudioClip]s and saves clips back in the file's
/// own format.
///
/// WAV files are read and written here; other formats go through a WAV
/// file converted by `afconvert`, built into macOS, or by `ffmpeg` when it
/// is installed: `afconvert` reads every format the editor opens but
/// writes only AAC and FLAC, so writing MP3 or Ogg needs `ffmpeg`.
class AudioFileService {
  /// Creates the service, converting formats through [_runner].
  const AudioFileService(this._runner);

  /// Lowercase extension of WAV files, without its dot.
  static const String wavExtension = 'wav';

  /// macOS's audio file converter.
  static const String _afconvert = 'afconvert';

  /// `afconvert`'s file format and data format arguments for each
  /// extension it writes.
  static const Map<String, List<String>> _afconvertFormats = {
    wavExtension: ['-f', 'WAVE', '-d', 'LEI16'],
    'm4a': ['-f', 'm4af', '-d', 'aac'],
    'aac': ['-f', 'adts', '-d', 'aac'],
    'flac': ['-f', 'flac', '-d', 'flac'],
  };

  /// The cross-platform audio and video converter.
  static const String _ffmpeg = 'ffmpeg';

  /// Name, without its extension, of the files converted through.
  static const String _scratchName = 'audio';

  /// Prefix of the temporary folders conversions run in.
  static const String _temporaryPrefix = 'fide_audio_';

  /// Launches the converters.
  final ProcessRunner _runner;

  /// Loads the sound at [path] with the outline of its waveform in
  /// [peakCount] slices.
  ///
  /// Throws a [ProcessException] when no converter reads its format, and a
  /// [FormatException] when its samples can't be read.
  Future<LoadedAudio> load(String path, {required int peakCount}) async {
    if (FileTypeUtils.extensionOf(path) == wavExtension) {
      try {
        return await _decode(await File(path).readAsBytes(), peakCount);
      } on FormatException {
        // A compressed WAV, such as ADPCM: a converter reads it below
      }
    }
    return _inTemporaryFolder((folder) async {
      final wav = p.join(folder, '$_scratchName.$wavExtension');
      await _convert(path, wav);
      return _decode(await File(wav).readAsBytes(), peakCount);
    });
  }

  /// Saves [clip] to [path], in the format its extension names.
  ///
  /// Throws a [ProcessException] when no converter writes that format.
  Future<void> save(AudioClip clip, String path) async {
    final extension = FileTypeUtils.extensionOf(path);
    if (extension == wavExtension) return writeWav(clip, path);
    await _inTemporaryFolder((folder) async {
      final wav = p.join(folder, '$_scratchName.$wavExtension');
      await writeWav(clip, wav);
      final converted = p.join(folder, '$_scratchName.$extension');
      await _convert(wav, converted);
      await File(converted).copy(path);
    });
  }

  /// Writes [clip] to [path] as a WAV file.
  Future<void> writeWav(AudioClip clip, String path) async {
    final bytes = await Isolate.run(() => WavCodec.encode(clip));
    await File(path).writeAsBytes(bytes, flush: true);
  }

  /// Converts the sound file [source] to [target], in the format of
  /// [target]'s extension, with the first converter that can.
  Future<void> _convert(String source, String target) async {
    final extension = FileTypeUtils.extensionOf(target);
    final afconvertFormat = _afconvertFormats[extension];
    final commands = [
      if (afconvertFormat != null)
        [_afconvert, ...afconvertFormat, source, target],
      [_ffmpeg, '-v', 'error', '-y', '-i', source, '-vn', target],
    ];
    for (final command in commands) {
      try {
        final result = await _runner.run(command.first, command.sublist(1));
        if (result.exitCode == 0 && File(target).existsSync()) return;
      } on ProcessException {
        // Not installed: try the next converter
      }
    }
    throw ProcessException(
      _ffmpeg,
      const [],
      'Converting .${FileTypeUtils.extensionOf(source)} to .$extension '
      'audio needs ffmpeg',
    );
  }

  /// The sound in the WAV file [bytes], decoded and outlined off the UI
  /// isolate.
  static Future<LoadedAudio> _decode(Uint8List bytes, int peakCount) =>
      Isolate.run(() {
        final clip = WavCodec.decode(bytes);
        return (clip: clip, peaks: clip.peaks(peakCount));
      });

  /// Runs [work] in a new temporary folder, deleted once it ends.
  static Future<T> _inTemporaryFolder<T>(
    Future<T> Function(String folder) work,
  ) async {
    final folder = await Directory.systemTemp.createTemp(_temporaryPrefix);
    try {
      return await work(folder.path);
    } finally {
      await folder.delete(recursive: true);
    }
  }
}
