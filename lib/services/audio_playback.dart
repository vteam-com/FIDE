import 'dart:async';
import 'dart:io';

import 'package:fide/models/audio_clip.dart';
import 'package:fide/services/audio_file_service.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:path/path.dart' as p;

/// Plays [AudioClip]s, one at a time, with the desktop's own sound player,
/// from a WAV file in a temporary folder that [dispose] deletes.
class AudioPlayback {
  /// Creates a player playing through [_shell], writing its WAV file with
  /// [_files].
  AudioPlayback(this._shell, this._files);

  /// Name of the WAV file played.
  static const String _fileName = 'preview.${AudioFileService.wavExtension}';

  /// Prefix of the temporary folder holding the file played.
  static const String _folderPrefix = 'fide_playback_';

  /// Writes the WAV file played.
  final AudioFileService _files;

  /// Starts the sound player.
  final DesktopShell _shell;

  /// Temporary folder of the file played, made on the first play.
  Directory? _folder;

  /// Counts plays and stops, so a play outdated while it starts stops.
  int _generation = 0;

  /// The player playing, or null when none is.
  Process? _process;

  /// The clip last written to the played file, so playing it again doesn't
  /// rewrite it.
  AudioClip? _written;

  /// Stops playing and deletes the temporary folder.
  Future<void> dispose() async {
    stop();
    final folder = _folder;
    _folder = null;
    if (folder != null && folder.existsSync()) {
      await folder.delete(recursive: true);
    }
  }

  /// Plays [clip], stopping what was playing; calls [onStarted] once the
  /// sound starts, and completes when it ends or is stopped.
  Future<void> play(AudioClip clip, {void Function()? onStarted}) async {
    stop();
    final generation = _generation;
    final folder = _folder ??= await Directory.systemTemp.createTemp(
      _folderPrefix,
    );
    final file = p.join(folder.path, _fileName);
    if (!identical(clip, _written)) {
      _written = null;
      await _files.writeWav(clip, file);
      _written = clip;
    }
    if (generation != _generation) return;
    final process = await _shell.playSound(file);
    if (generation != _generation) {
      process.kill();
      return;
    }
    _process = process;
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    onStarted?.call();
    await process.exitCode;
    if (identical(_process, process)) _process = null;
  }

  /// Stops the clip playing, if any.
  void stop() {
    _generation++;
    _process?.kill();
    _process = null;
  }
}
