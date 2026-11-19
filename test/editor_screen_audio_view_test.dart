import 'dart:async';
import 'dart:io';

import 'package:fide/panels/center/editor/editor_screen_audio_view.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/wav_codec.dart';
import 'package:fide/widgets/audio_waveform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'audio_test_support.dart';

import 'widget_test_support.dart';

void main() {
  late Directory folder;
  late FakeShell shell;

  /// What the editor's Save would run, as the view last reported it.
  AsyncCallback? pendingSave;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('audio_view_');
    shell = FakeShell();
    pendingSave = null;
  });
  tearDown(() => folder.deleteSync(recursive: true));

  /// Shows the audio editor of [path] and waits for it to load.
  Future<void> open(WidgetTester tester, String path) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          desktopShellProvider.overrideWithValue(shell),
          processRunnerProvider.overrideWithValue(FakeConverterRunner({})),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditorScreenAudioView(
              filePath: path,
              onSaveChanged: (save) => pendingSave = save,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// The button labelled [label].
  TextButton button(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
  );

  testWidgets('trims a sound, plays it and saves it over the file', (
    tester,
  ) async {
    final path = p.join(folder.path, 'jump.wav');
    File(path).writeAsBytesSync(WavCodec.encode(tone(seconds: 1)));
    await open(tester, path);
    expect(find.textContaining('8 kHz • Mono'), findsOneWidget);
    expect(find.text('0:01.000'), findsOneWidget);
    expect(pendingSave, isNull);
    expect(button(tester, 'Discard').onPressed, isNull);

    final waveform = tester.getRect(find.byType(AudioWaveform));
    await tester.dragFrom(
      waveform.centerLeft + const Offset(1, 0),
      Offset(waveform.width / 4, 0),
    );
    await tester.pump();
    await tester.pump();
    expect(pendingSave, isNotNull);
    expect(find.textContaining('0:00.7'), findsOneWidget);

    shell.processes.add(FakeProcess());
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester, until: () => shell.played.isNotEmpty);
    expect(find.byIcon(Icons.stop), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop));
    await settle(tester);
    expect(shell.processes.last.killed, true);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    var saved = false;
    unawaited(pendingSave!().then((_) => saved = true));
    await settle(tester, until: () => saved);
    expect(pendingSave, isNull);
    final sound = WavCodec.decode(File(path).readAsBytesSync());
    expect(sound.duration.inMilliseconds, closeTo(750, 10));
    expect(find.textContaining('0:00.7'), findsWidgets);
  });

  testWidgets('speed and pitch change the edit; Discard undoes it', (
    tester,
  ) async {
    final path = p.join(folder.path, 'loop.wav');
    File(path).writeAsBytesSync(WavCodec.encode(tone(seconds: 1, channels: 2)));
    await open(tester, path);
    expect(find.textContaining('Stereo'), findsOneWidget);
    final sliders = find.byType(Slider);
    await tester.tapAt(
      tester.getRect(sliders.first).centerRight - const Offset(8, 0),
    );
    await tester.pump();
    expect(find.text('200%'), findsOneWidget);
    expect(find.text('0:00.500'), findsOneWidget);
    await tester.tapAt(
      tester.getRect(sliders.last).centerLeft + const Offset(8, 0),
    );
    await tester.pump();
    expect(find.text('-12 st'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0 st'), findsOneWidget);
    expect(button(tester, 'Discard').onPressed, isNull);
  });

  testWidgets('says why a sound can not be opened', (tester) async {
    final path = p.join(folder.path, 'broken.wav');
    File(path).writeAsStringSync('not a sound');
    await open(tester, path);
    await settle(
      tester,
      until: () => find.text("Can't open this sound").evaluate().isNotEmpty,
    );
    expect(find.text("Can't open this sound"), findsOneWidget);
    expect(find.textContaining('needs ffmpeg'), findsOneWidget);
  });
}
