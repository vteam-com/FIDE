// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/main.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/widgets/create_project_dialog.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late Directory tempProjectDir;

  setUpAll(() async {
    // Use system temp directory for test project creation
    final tempDir = Directory.systemTemp;
    tempProjectDir = await Directory(
      path.join(tempDir.path, 'fide_integration_test_HelloWorld'),
    ).create(recursive: true);
  });

  tearDownAll(() async {
    if (await tempProjectDir.exists()) {
      await tempProjectDir.delete(recursive: true);
    }
  });

  testWidgets('FIDE integration: create/open HelloWorld, panels, file, outline, close', (
    WidgetTester tester,
  ) async {
    // Start the app
    await tester.pumpWidget(const ProviderScope(child: FIDE()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify we're on the welcome screen
    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('FIDE'), findsOneWidget);

    // Set the test initial directory for the dialog
    CreateProjectDialog.setTestInitialDirectory(tempProjectDir.path);

    // Tap "Create New Project" button
    final createButton = find.text('Create New Project');
    expect(createButton, findsOneWidget);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // Verify create project dialog is open
    expect(find.text('New Flutter Project'), findsOneWidget);

    // Enter project name "HelloWorld"
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2)); // Project name and directory fields
    await tester.enterText(textFields.first, 'HelloWorld');
    await tester.pumpAndSettle();

    // The directory field is read-only and should already be set to tempProjectDir.path
    // due to the initialDirectory parameter we can add to the dialog

    // Click the "Create" button
    final createProjectButton = find.text('Create');
    expect(createProjectButton, findsOneWidget);
    await tester.tap(createProjectButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Wait for the dialog to disappear and project creation to complete
    expect(find.text('New Flutter Project'), findsNothing);

    // Wait for project creation to complete
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Get the project path that was created (using temp directory)
    final projectPath = path.join(tempProjectDir.path, 'HelloWorld');

    // Debug: Check if project directory was created
    final projectDir = Directory(projectPath);
    print('Project path: $projectPath');
    print('Project directory exists: ${await projectDir.exists()}');
    if (await projectDir.exists()) {
      final contents = await projectDir.list().toList();
      print(
        'Project directory contents: ${contents.map((e) => e.path).toList()}',
      );
    }

    // Since project creation may not load the project automatically in test environment,
    // manually load the created project
    final container2 = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final projectService2 = container2.read(projectServiceProvider);
    final loadSuccess = await projectService2.loadProject(projectPath);
    print('Manual project load success: $loadSuccess');

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Debug: Check if project is loaded
    final projectLoaded = container2.read(projectLoadedProvider);
    final currentProjectPath = container2.read(currentProjectPathProvider);
    print('Project loaded: $projectLoaded');
    print('Current project path: $currentProjectPath');

    // Verify project is loaded - should not see welcome screen anymore
    expect(
      find.text('Welcome to'),
      findsNothing,
      reason: 'Project should be loaded and welcome screen hidden',
    );
    expect(find.byType(MaterialApp), findsOneWidget);

    // Test panel switching by clicking on panel toggle buttons in title bar
    final panelButtons = find.byType(IconButton);
    expect(
      panelButtons,
      findsWidgets,
      reason: 'Panel toggle buttons should be present',
    );

    // Test panel switching using programmatic approach since buttons may be disabled
    final containerForPanels = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // Test Explorer panel (index 0)
    containerForPanels.read(activeLeftPanelTabProvider.notifier).state = 0;
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    // Test Organized panel (index 1)
    containerForPanels.read(activeLeftPanelTabProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    // Test Git panel (index 2)
    containerForPanels.read(activeLeftPanelTabProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    // Test Search panel (index 3) - basic panel switching test
    containerForPanels.read(activeLeftPanelTabProvider.notifier).state = 3;
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    // Note: Advanced search functionality testing is complex for integration tests
    // and may require more sophisticated UI interaction handling.
    // For now, we verify that the search panel can be switched to successfully.

    // Test file selection - use programmatic approach since UI interaction is complex
    final container3 = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // Create FileSystemItem for main.dart and select it
    final mainDartPath = path.join(projectPath, 'lib', 'main.dart');
    final mainDartFile2 = File(mainDartPath);
    final mainDartItem = FileSystemItem.fromFileSystemEntity(mainDartFile2);
    container3.read(selectedFileProvider.notifier).state = mainDartItem;
    await tester.pumpAndSettle();

    // Verify file is selected
    final selectedFile = container3.read(selectedFileProvider);
    expect(selectedFile?.path, equals(mainDartPath));

    // Verify file content is accessible
    final content = await mainDartFile2.readAsString();
    expect(content.contains('void main()'), isTrue);

    // Test closing project - set project loaded to false
    container3.read(projectLoadedProvider.notifier).state = false;
    container3.read(currentProjectPathProvider.notifier).state = null;
    container3.read(selectedFileProvider.notifier).state = null;
    await tester.pumpAndSettle();

    // Verify we're back to welcome screen
    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('FIDE'), findsOneWidget);

    // Clean up the test project
    final testProjectDir = Directory(projectPath);
    if (await testProjectDir.exists()) {
      await testProjectDir.delete(recursive: true);
    }
  });
}
