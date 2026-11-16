import 'dart:io';

import 'package:fide/services/audio_file_service.dart';
import 'package:fide/services/wav_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'audio_test_support.dart';

void main() {
  late Directory folder;

  setUp(() async => folder = await Directory.systemTemp.createTemp('audio_'));
  tearDown(() => folder.delete(recursive: true));

  test('loads a WAV file without converting it', () async {
    final runner = FakeConverterRunner({});
    final path = p.join(folder.path, 'tone.wav');
    await File(path).writeAsBytes(WavCodec.encode(tone(seconds: 0.5)));
    final audio = await AudioFileService(runner).load(path, peakCount: 8);
    expect(audio.clip.duration, const Duration(milliseconds: 500));
    expect(audio.peaks, hasLength(8));
    expect(runner.commands, isEmpty);
  });

  test('converts other formats, and WAV it can not read, with afconvert '
      'then ffmpeg', () async {
    final runner = FakeConverterRunner({'ffmpeg'});
    final mp3 = p.join(folder.path, 'tone.mp3');
    await File(mp3).writeAsString('ID3');
    final audio = await AudioFileService(runner).load(mp3, peakCount: 4);
    expect(audio.clip.sampleRate, testSampleRate);
    expect(runner.commands.first, startsWith('afconvert -f WAVE -d LEI16 '));
    expect(runner.commands.last, startsWith('ffmpeg -v error -y -i $mp3'));

    final adpcm = p.join(folder.path, 'adpcm.wav');
    await File(adpcm).writeAsString('RIFF....WAVE');
    runner.commands.clear();
    await AudioFileService(runner).load(adpcm, peakCount: 4);
    expect(runner.commands, hasLength(2));
  });

  test('fails naming ffmpeg when no converter reads the format', () async {
    final ogg = p.join(folder.path, 'tone.ogg');
    await File(ogg).writeAsString('OggS');
    expect(
      AudioFileService(FakeConverterRunner({})).load(ogg, peakCount: 4),
      throwsA(
        isA<ProcessException>().having(
          (error) => error.message,
          'message',
          contains('needs ffmpeg'),
        ),
      ),
    );
  });

  test('saves WAV itself and other formats through a converter', () async {
    final runner = FakeConverterRunner({'afconvert'});
    final service = AudioFileService(runner);
    final wav = p.join(folder.path, 'out.wav');
    await service.save(tone(seconds: 0.25), wav);
    expect(
      WavCodec.decode(await File(wav).readAsBytes()).duration,
      const Duration(milliseconds: 250),
    );
    expect(runner.commands, isEmpty);

    final m4a = p.join(folder.path, 'out.m4a');
    await service.save(tone(), m4a);
    expect(runner.commands.single, startsWith('afconvert -f m4af -d aac '));
    expect(File(m4a).existsSync(), true);

    // afconvert doesn't write MP3
    final mp3 = p.join(folder.path, 'out.mp3');
    await expectLater(
      service.save(tone(), mp3),
      throwsA(isA<ProcessException>()),
    );
  });
}
