import 'package:fide/widgets/audio_waveform.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'paint_layer_support.dart';

void main() {
  testWidgets('scrolling a diff moves the minimap band, not its marks', (
    tester,
  ) async {
    final oldLines = [for (var i = 0; i < 400; i++) 'line $i'];
    final newLines = [
      for (var i = 0; i < 400; i++) i % 25 == 0 ? 'changed $i' : 'line $i',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 300,
            child: SideBySideDiff(
              oldText: oldLines.join('\n'),
              newText: newLines.join('\n'),
            ),
          ),
        ),
      ),
    );
    final marks = findPainter('_DiffMinimapMarksPainter');
    final band = findPainter('_DiffMinimapBandPainter');
    final marksBefore = paintedLayers(tester, marks);
    final bandBefore = paintedLayers(tester, band);
    expect(marksBefore, isNotEmpty);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump();

    expect(paintedLayers(tester, marks), samePaintedLayers(marksBefore));
    expect(paintedLayers(tester, band), isNot(samePaintedLayers(bandBefore)));
  });

  testWidgets('the playhead moves without painting the waveform again', (
    tester,
  ) async {
    final playhead = ValueNotifier<double?>(0.1);
    addTearDown(playhead.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 100,
            child: AudioWaveform(
              peaks: Float32List.fromList([
                for (var i = 0; i < 4096; i++) (i % 100) / 100,
              ]),
              start: 0.2,
              end: 0.8,
              playhead: playhead,
              onTrimmed: (_, _) {},
            ),
          ),
        ),
      ),
    );
    final waveform = findPainter('_AudioWaveformPainter');
    final playheadLayer = findPainter('_AudioPlayheadPainter');
    final waveformBefore = paintedLayers(tester, waveform);
    final playheadBefore = paintedLayers(tester, playheadLayer);
    expect(waveformBefore, isNotEmpty);

    playhead.value = 0.5;
    await tester.pump();

    expect(paintedLayers(tester, waveform), samePaintedLayers(waveformBefore));
    expect(
      paintedLayers(tester, playheadLayer),
      isNot(samePaintedLayers(playheadBefore)),
    );
  });
}
