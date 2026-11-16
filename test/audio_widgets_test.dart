import 'dart:io';
import 'dart:typed_data';

import 'package:fide/models/audio_edit.dart';
import 'package:fide/models/clock_time.dart';
import 'package:fide/widgets/audio_waveform.dart';
import 'package:fide/widgets/compact_slider.dart';
import 'package:fide/widgets/file_facts_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

void main() {
  test('clockLabel shows minutes, seconds and milliseconds', () {
    expect(Duration.zero.clockLabel, '0:00.000');
    expect(const Duration(milliseconds: 2350).clockLabel, '0:02.350');
    expect(const Duration(minutes: 12, seconds: 5).clockLabel, '12:05.000');
  });

  testWidgets('dragging the waveform moves the nearest trim handle', (
    tester,
  ) async {
    var start = 0.0;
    var end = 1.0;
    final playhead = ValueNotifier<double?>(0.5);
    addTearDown(playhead.dispose);
    Widget build() => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 100,
          child: AudioWaveform(
            peaks: Float32List.fromList([0, 0.5, 1, 0.5]),
            start: start,
            end: end,
            playhead: playhead,
            onTrimmed: (newStart, newEnd) {
              start = newStart;
              end = newEnd;
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(build());
    final waveform = tester.getTopLeft(find.byType(AudioWaveform));

    await tester.dragFrom(waveform + const Offset(10, 50), const Offset(90, 0));
    expect(start, closeTo(0.25, 0.05));
    expect(end, 1);

    await tester.pumpWidget(build());
    await tester.dragFrom(
      waveform + const Offset(390, 50),
      const Offset(-500, 0),
    );
    expect(end, closeTo(start + AudioEdit.minKeptShare, 1e-9));

    playhead.value = null;
    await tester.pumpWidget(build());
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compact slider reports its values', (tester) async {
    double? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: CompactSlider(
              value: 0,
              max: 10,
              divisions: 10,
              onChanged: (newValue) => value = newValue,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    expect(value, 5);
  });

  testWidgets('file facts show the facts, size and format', (tester) async {
    final folder = Directory.systemTemp.createTempSync('facts_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File(p.join(folder.path, 'jump.wav'))
      ..writeAsBytesSync(List.filled(2048, 0));
    final other = File(p.join(folder.path, 'b.mp3'))..writeAsBytesSync([0]);
    Widget build(String path) => MaterialApp(
      home: FileFactsLabel(filePath: path, facts: const ['Mono']),
    );
    await tester.runAsync(() => tester.pumpWidget(build(file.path)));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Mono • 2.0 KB • WAV'), findsOneWidget);

    await tester.runAsync(() => tester.pumpWidget(build(other.path)));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Mono • 1.0 B • MP3'), findsOneWidget);
  });
}
