import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fide/models/audio_clip.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/wav_codec.dart';

/// Sample rate of the test tones.
const int testSampleRate = 8000;

/// A sine of [frequency] Hz lasting [seconds], on [channels] channels.
AudioClip tone({
  double frequency = 200,
  double seconds = 1,
  int channels = 1,
  double amplitude = 0.5,
}) {
  final frames = (testSampleRate * seconds).round();
  final samples = Float32List(frames);
  for (var frame = 0; frame < frames; frame++) {
    samples[frame] =
        amplitude * math.sin(2 * math.pi * frequency * frame / testSampleRate);
  }
  return AudioClip(
    sampleRate: testSampleRate,
    channels: [
      for (var c = 0; c < channels; c++) Float32List.fromList(samples),
    ],
  );
}

/// The frequency of [samples], in Hz, from its upward zero crossings,
/// ignoring the first and last tenth where windows fade.
double frequencyOf(Float32List samples, int sampleRate) {
  final from = samples.length ~/ 10;
  final to = samples.length - from;
  var crossings = 0;
  for (var index = from + 1; index < to; index++) {
    if (samples[index - 1] < 0 && samples[index] >= 0) crossings++;
  }
  return crossings * sampleRate / (to - from);
}

/// A sound player process that plays until killed or [finish]ed.
class FakeProcess implements Process {
  final Completer<int> _exit = Completer();

  bool killed = false;

  /// Ends the sound as if it played to its end.
  void finish() {
    if (!_exit.isCompleted) _exit.complete(0);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    finish();
    return true;
  }
}

/// A macOS shell whose player is a [FakeProcess], recording each file.
class FakeShell extends MacDesktopShell {
  FakeShell() : super(const ProcessRunner());

  final List<String> played = [];

  final List<FakeProcess> processes = [];

  @override
  Future<Process> playSound(String file) async {
    played.add(file);
    return processes.last;
  }
}

/// Converts with the tools in [installed] by writing a test tone to the
/// last argument, and throws as if missing for the others.
class FakeConverterRunner extends ProcessRunner {
  FakeConverterRunner(this.installed);

  final Set<String> installed;

  final List<String> commands = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String> environment = const {},
  }) async {
    commands.add([executable, ...arguments].join(' '));
    if (!installed.contains(executable)) {
      throw ProcessException(executable, arguments, 'No such file');
    }
    await File(arguments.last).writeAsBytes(WavCodec.encode(tone()));
    return ProcessResult(0, 0, '', '');
  }
}
