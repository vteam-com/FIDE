// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fide/app_bootstrap.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/main.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/project_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import 'steps.dart';

/// The project shown in the screenshots: this repository, passed with
/// `--dart-define=FIDE_ROOT=$PWD` (see tool/screenshots.sh).
const String _projectPath = String.fromEnvironment('FIDE_ROOT');

/// Time for the project analysis (fCheck, Git, tests) to finish.
const Duration _analysisTime = Duration(seconds: 30);

/// Time for a tab switch or an opened file to render.
const Duration _renderTime = Duration(seconds: 2);

/// Wraps the app so its pixels can be read back.
final GlobalKey _appKey = GlobalKey();

/// Pumps frames for [duration] of real time, letting async work finish.
Future<void> _settleFor(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 100);
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(frame);
  }
}

/// Saves the app as it is drawn to docs/screenshots/[name].png.
Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _appKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final pixelRatio = tester.view.devicePixelRatio;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(
    path.join(_projectPath, 'docs', 'screenshots', '$name.png'),
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  substep('📸 ${file.path}');
}

/// Taps the tab or button keyed [key] and lets it render.
Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await _settleFor(tester, _renderTime);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The app reopens the first recent project when it starts
  SharedPreferences.setMockInitialValues({
    PrefKeys.mruFolders: [_projectPath],
  });

  testWidgets('README screenshots', (WidgetTester tester) async {
    expect(_projectPath, isNotEmpty, reason: 'Pass --dart-define=FIDE_ROOT');
    final container = ProviderContainer(
      overrides: [
        projectTreeLoaderProvider.overrideWithValue(loadProjectTreeInline),
      ],
    );

    stepStart('Open $_projectPath');
    await initializeWindowManager();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _appKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const FIDE(),
        ),
      ),
    );
    await _settleFor(tester, _analysisTime);
    stepStop();

    stepStart('Project overview');
    await _tapKey(tester, 'keyTabOrganize');
    await _tapKey(tester, 'keyTabInfo');
    await _capture(tester, 'overview');
    stepStop();

    stepStart('Editor');
    container
        .read(selectedFileProvider.notifier)
        .state = FileSystemItem.fromPath(
      path.join(_projectPath, 'lib', 'panels', 'right', 'ai_panel.dart'),
    );
    await _settleFor(tester, _renderTime);
    await _tapKey(tester, 'keyTabFolder');
    await _tapKey(tester, 'keyTabOutline');
    await _capture(tester, 'editor');
    stepStop();

    stepStart('AI transcript');
    final chat = container.read(aiChatProvider.notifier);
    chat.beginTask('What does the AI panel do when a reply is pending?');
    chat.addReply(
      '🔧 read_file lib/panels/right/ai_panel.dart',
      isProgress: true,
    );
    chat.endTask(
      'While a reply is pending, `AiChat.isBusy` is true and the panel:\n\n'
      '- shows a **Working…** line at the end of the transcript\n'
      '- swaps the Send button for **Stop**, also bound to `Esc`\n'
      '- ignores Enter, so a second prompt is not sent\n\n'
      '```dart\n'
      'if (chat.isBusy) return;\n'
      '```',
    );
    await _tapKey(tester, 'keyTabAI');
    await _capture(tester, 'ai');
    stepStop();

    stepStart('Git');
    await _tapKey(tester, 'keyTabGit');
    await _tapKey(tester, 'keyTabInfo');
    // The README's diff against HEAD, in place of the open file
    await _tapKey(tester, 'keyEditorClose');
    await tester.tap(find.text('README.md').first);
    await _settleFor(tester, _renderTime);
    await _capture(tester, 'git');
    stepStop();
  });
}
