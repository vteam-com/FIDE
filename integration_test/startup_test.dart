import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/controllers/app_controller.dart';
import 'package:fide/main.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/file_system_watcher.dart';
import 'package:fide/providers/project_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// Polling interval while waiting for the async startup chain.
const Duration _pollInterval = Duration(milliseconds: 200);

/// Upper bound on polls before the startup wait gives up.
const int _maxPolls = 100;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup reopens the most recent project and its last file', (
    WidgetTester tester,
  ) async {
    // Minimal Flutter project that passes ProjectService validation
    final project = Directory.systemTemp.createTempSync('fide_startup_');
    addTearDown(() => project.deleteSync(recursive: true));
    File(path.join(project.path, 'pubspec.yaml')).writeAsStringSync(
      'name: startup\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    Directory(path.join(project.path, 'lib')).createSync();
    final mainDart = path.join(project.path, 'lib', 'main.dart');
    File(mainDart).writeAsStringSync('void main() {}\n');

    SharedPreferences.setMockInitialValues({
      PrefKeys.mruFolders: [project.path],
      PrefKeys.lastOpenedFile: mainDart,
    });

    final container = ProviderContainer(
      overrides: [
        projectTreeLoaderProvider.overrideWithValue(loadProjectTreeInline),
        fileSystemWatcherProvider.overrideWith(
          (_) => FileSystemWatcher(watchEnabled: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider).initializeWindowManager();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FIDE()),
    );

    // Startup awaits preferences and project loading between frames
    final openTab = find.descendant(
      of: find.byKey(const Key('keyMruForFiles')),
      matching: find.text('main.dart'),
    );
    for (var i = 0; i < _maxPolls && openTab.evaluate().isEmpty; i++) {
      await tester.pump(_pollInterval);
    }

    expect(container.read(currentProjectPathProvider), project.path);
    expect(container.read(mruFoldersProvider).first, project.path);
    expect(openTab, findsOneWidget);
  });
}
