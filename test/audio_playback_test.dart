import 'dart:async';
import 'dart:io';

import 'package:fide/services/audio_file_service.dart';
import 'package:fide/services/audio_playback.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_test_support.dart';

void main() {
  test('plays a clip from a WAV file until it ends or is stopped', () async {
    final shell = FakeShell()..processes.add(FakeProcess());
    final playback = AudioPlayback(
      shell,
      const AudioFileService(ProcessRunner()),
    );
    final clip = tone(seconds: 0.1);
    final started = Completer<void>();
    final playing = playback.play(clip, onStarted: started.complete);
    await started.future;
    expect(File(shell.played.single).existsSync(), true);
    shell.processes.last.finish();
    await playing;

    shell.processes.add(FakeProcess());
    final restarted = Completer<void>();
    final again = playback.play(clip, onStarted: restarted.complete);
    await restarted.future;
    playback.stop();
    await again;
    expect(shell.processes.last.killed, true);
    expect(shell.played, hasLength(2));

    final folder = File(shell.played.first).parent;
    await playback.dispose();
    expect(folder.existsSync(), false);
  });

  test('a play stopped while it starts never plays', () async {
    final shell = FakeShell()..processes.add(FakeProcess());
    final playback = AudioPlayback(
      shell,
      const AudioFileService(ProcessRunner()),
    );
    final playing = playback.play(tone(seconds: 0.1));
    playback.stop();
    await playing;
    expect(shell.played, isEmpty);
    await playback.dispose();
  });
}
