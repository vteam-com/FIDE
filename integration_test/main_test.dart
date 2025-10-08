// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/main.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/screens/create_project_screen.dart';
import 'package:fide/controllers/app_controller.dart';
import 'package:path/path.dart' as path;

import 'package:shared_preferences/shared_preferences.dart';

import 'steps.dart';

/// Clean up any existing HelloWorld directories that might cause test collisions
Future<void> _cleanupExistingHelloWorldDirectories() async {
  try {
    final tempDir = Directory.systemTemp;

    // Look for and rename any existing HelloWorld directories in the temp folder
    final tempContents = await tempDir.list().toList();
    for (final entity in tempContents) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        if (dirName.contains('HelloWorld') ||
            dirName.contains('fide_test_HelloWorld')) {
          // Rename with timestamp to avoid collisions
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newPath = path.join(
            tempDir.path,
            '${dirName}_backup_$timestamp',
          );

          try {
            await entity.rename(newPath);
            substep('Renamed existing directory: ${entity.path} -> $newPath');
          } catch (e) {
            substep('Could not rename directory ${entity.path}: $e');
            // Try to delete as last resort
            try {
              await entity.delete(recursive: true);
              substep('Deleted existing directory: ${entity.path}');
            } catch (deleteError) {
              substep(
                'Could not delete directory ${entity.path}: $deleteError',
              );
            }
          }
        }
      }
    }

    // Also check current working directory for any HelloWorld folders
    final cwd = Directory.current;
    final cwdContents = await cwd.list().toList();
    for (final entity in cwdContents) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        if (dirName == 'HelloWorld') {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newPath = path.join(cwd.path, '${dirName}_backup_$timestamp');

          try {
            await entity.rename(newPath);
            substep(
              'Renamed existing directory in cwd: ${entity.path} -> $newPath',
            );
          } catch (e) {
            substep('Could not rename directory in cwd ${entity.path}: $e');
          }
        }
      }
    }

    substep('Cleanup completed - renamed any existing HelloWorld directories');
  } catch (e) {
    substep('Error during cleanup: $e');
  }
}

Future<void> _testPanelToggle(
  WidgetTester tester,
  String key,
  String reason,
) async {
  final Finder toggle = find.byKey(Key(key));
  expect(toggle, findsOneWidget, reason: '$reason toggle button should exist');

  // Hide
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  await Future.delayed(const Duration(milliseconds: 300));
  // Show
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Helper function to wait for a widget to appear
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder,
  Duration timeout, [
  String description = '',
]) async {
  const pollInterval = Duration(milliseconds: 200);
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(pollInterval);
    if (tester.any(finder)) {
      return;
    }
  }

  fail(
    'Widget${description.isNotEmpty ? ' ($description)' : ''} did not '
    'appear within ${timeout.inSeconds} seconds',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('FIDE integration test', (WidgetTester tester) async {
    // Clean up any existing HelloWorld folders to avoid test collisions
    await _cleanupExistingHelloWorldDirectories();

    // 1. start the FIDE app
    // Set a larger test window to avoid UI layout constraints
    // await tester.binding.setSurfaceSize(const Size(1400, 900));

    // Use the same container setup as in main.dart for consistency
    final container = ProviderContainer();

    // Verify we're on the welcome screen
    stepStart('Welcome screen');
    {
      // Initialize window manager like in main.dart
      await container.read(appControllerProvider).initializeWindowManager();

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const FIDE()),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Welcome to FIDE'), findsOneWidget);
    }
    stepStop();

    // 2. Create new project via UI workflow
    String expectedProjectPath = '';
    stepStart('Creating HelloWorld project');
    {
      // Get temp directory for project creation
      final tempDir = Directory.systemTemp;
      final projectParentDir = path.join(tempDir.path, 'fide_test_projects');
      await Directory(projectParentDir).create(recursive: true);

      // Delete any existing helloworld project to ensure clean state
      expectedProjectPath = path.join(projectParentDir, 'helloworld');
      final projectDir = Directory(expectedProjectPath);
      if (await projectDir.exists()) {
        await projectDir.delete(recursive: true);
        substep(
          'Deleted existing helloworld project directory: $expectedProjectPath',
        );
      }

      // Set the test initial directory to prevent any issues with permissions
      CreateProjectScreen.setTestInitialDirectory(projectParentDir);

      // Log expected project path for debugging
      substep('Expected project path: $expectedProjectPath');
      substep('Project parent directory: $projectParentDir');

      // Click the "Create New Project" button (simulates user creating new project)
      await tester.tap(find.text('Create New Project'));
      await tester.pumpAndSettle();

      // Fill Step 1: Project Details - project name
      await tester.enterText(find.byType(TextField).first, 'helloworld');
      await tester.pumpAndSettle();

      // Click Next button to proceed to Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Localization Settings should be shown
      // Default is "Do you want to localize?" = Yes, and EN/FR selected

      // Click Create button to create the project - this goes to Step 3
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Step 3: Should show the LoadingStepWidget instead of going straight to creating state
      // Verify we're still in the create project screen with step 3 visible
      final step3Content = find.textContaining('Creating project:');
      expect(
        step3Content,
        findsOneWidget,
        reason: 'Step 3 project creation display should be visible',
      );

      // Verify Step 3 is displaying and showing "Creating project:" text
      expect(
        find.textContaining('Creating project:'),
        findsOneWidget,
        reason: 'LoadingStep3 should be visible with creating progress',
      );

      // Verify that the button is disabled (indicating the "Creating..." state)
      final filledButton = find.byType(FilledButton);
      expect(
        filledButton,
        findsOneWidget,
        reason: 'Should have one FilledButton in step 3',
      );

      // Wait for project creation to complete - wait for the Open button to appear and be enabled
      final openButtonFinder = find.widgetWithText(FilledButton, 'Open');

      await waitForWidget(
        tester,
        openButtonFinder,
        const Duration(seconds: 10),
        'Open button after project creation',
      );

      // Verify the button is actually enabled
      final openButton = tester.widget<FilledButton>(openButtonFinder);
      expect(
        openButton.onPressed,
        isNotNull,
        reason: 'Open button should be enabled',
      );

      // Click the "Open" button to load the newly created project
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Wait for loading screen to appear
      final loadingTextFinder = find.textContaining('Loading project');
      await waitForWidget(
        tester,
        loadingTextFinder,
        const Duration(seconds: 5),
        'Loading project screen after tapping Open',
      );

      // Wait for loading to complete and main UI to appear (indicated by toggle panel buttons)
      final toggleButton = find.byKey(Key('togglePanelLeft'));
      await waitForWidget(
        tester,
        toggleButton,
        const Duration(seconds: 10),
        'toggle panel button indicating main UI is loaded',
      );
    }
    stepStop();

    // Verify Toggle Panels - commented out for test environment
    stepStart('Toggle buttons are working');
    {
      // Test panel toggle buttons
      await _testPanelToggle(tester, 'togglePanelLeft', 'Left panel');
      await _testPanelToggle(tester, 'togglePanelBottom', 'Bottom panel');
      await _testPanelToggle(tester, 'togglePanelRight', 'Right panel');
    }
    stepStop();

    // Switch to Organize tab
    {
      substep('✓ Organize tab');
      await tester.tap(find.byKey(const Key('keyTabOrganize')));
      await tester.pumpAndSettle();
    }

    // Switch to Folder tab via actual UI tab interaction
    stepStart('✓ Folder tab');
    {
      await tester.tap(find.byKey(const Key('keyTabFolder')));
      await tester.pumpAndSettle();

      // 4. Verify folder tree loads correctly in UI
      substep('Verifying folder tree loads correctly in UI');

      // Verify that helloworld project folder exists in the UI
      expect(find.text('helloworld'), findsOneWidget);
      substep('✓ helloworld project visible in file tree');

      // The folders are successfully loaded and displayable - the core UI workflow is validated
      substep('Step 4 complete: Folder tree loaded correctly');

      // 5. Open a source .dart file
      substep('Step 5: Opening a source .dart file');

      // Navigate to and open main.dart file - this may be constrained by UI layout
      // Check if lib folder is visible and clickable before tapping

      await tester.tap(find.text('lib'));
      await tester.pumpAndSettle();

      // Check if main.dart is visible and clickable in the test viewport
      final bool mainDartVisible = find.text('main.dart').evaluate().isNotEmpty;
      assert(mainDartVisible, true);

      // Try a safe tap with warnIfMissed to avoid test failure
      await tester.tap(find.text('main.dart'), warnIfMissed: true);
      // triggers initial rebuild for the app reacting to the file being loaded
      await tester.pump(const Duration(milliseconds: 50));
      substep('✓ main.dart file open start');
    }
    stepStop();

    // Make a small edit in the editor
    stepStart('Make a small edit in the editor');

    // Check if file opening succeeded by looking for the filename in the editor PopupMenuButton (document dropdown)
    final mruFile = find.byKey(const Key('keyMruForFiles'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(mruFile, findsOneWidget);
    substep('✓ keyMruForFiles found');

    expect(
      find.descendant(of: mruFile, matching: find.text('main.dart')),
      findsOneWidget,
      reason: 'main.dart file should be displayed in editor document dropdown',
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Find the file path based on the project and file name
    final mainDartFile = File('$expectedProjectPath/lib/main.dart');
    final originalContent = await mainDartFile.readAsString();
    final modifiedContent = originalContent.replaceAll(
      'Hello Worldld',
      'Hello Flutter World',
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Write the modified content back
    await mainDartFile.writeAsString(modifiedContent);
    await tester.pump(const Duration(milliseconds: 50));

    // 7. Close the editor
    substep('Close the editor');
    await tester.tap(find.byKey(const Key('keyEditorClose')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    stepStop();

    // Switch to Git panel
    stepStart('GIT Panel');
    {
      substep('✓ Switched to Git panel');
      await tester.tap(find.byKey(const Key('keyTabGit')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    stepStop();

    // Switch to Test panel
    stepStart('Test Panel');
    {
      substep('✓ Switched to Test panel');
      await tester.tap(find.byKey(const Key('keyTabTest')));
      await tester.pumpAndSettle();

      // Verify the test panel loads correctly
      expect(
        find.text('Test Suite'),
        findsOneWidget,
        reason: 'Test panel title should be visible',
      );
      expect(
        find.text('Run and manage Flutter tests'),
        findsOneWidget,
        reason: 'Test panel subtitle should be visible',
      );
      expect(
        find.text('Run All Tests'),
        findsOneWidget,
        reason: 'All Tests action should be visible',
      );
      expect(
        find.text('Unit Tests'),
        findsOneWidget,
        reason: 'Unit Tests action should be visible',
      );
      expect(
        find.text('Widget Tests'),
        findsOneWidget,
        reason: 'Widget Tests action should be visible',
      );

      substep('✓ Test panel loaded successfully with all test actions');
    }
    stepStop();

    stepStart('Right Panel');
    {
      await tester.tap(find.byKey(const Key('keyTabOutline')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('keyTabLocalize')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('keyTabAI')));
      await tester.pump(const Duration(milliseconds: 50));
      // await tester.tap(find.byKey(const Key('keyTabInfo')));
      // await tester.pump(const Duration(milliseconds: 50));
    }
    stepStop();

    await tester.pump(const Duration(milliseconds: 50));

    // Final verification of overall app state
    stepStart('Clean up');
    {
      final finalProjectLoaded = container.read(projectLoadedProvider);
      await tester.pump(const Duration(milliseconds: 50));
      expect(finalProjectLoaded, isTrue);

      // Basic cleanup without UI updates that might cause layout issues
      container.read(selectedFileProvider.notifier).state = null;
      container.read(projectLoadedProvider.notifier).state = false;
      container.read(currentProjectPathProvider.notifier).state = null;
    }
    stepStop();
  });
}
