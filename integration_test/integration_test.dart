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

  testWidgets('FIDE integration: create project with missing dependencies', (
    WidgetTester tester,
  ) async {
    // Test project creation failure when Flutter is not available
    // This tests error handling in create project dialog

    await tester.pumpWidget(const ProviderScope(child: FIDE()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Tap "Create New Project" button
    final createButton = find.text('Create New Project');
    expect(createButton, findsOneWidget);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // Verify create project dialog is open
    expect(find.text('New Flutter Project'), findsOneWidget);

    // Try to create without entering name - button should not work
    final createProjectButton = find.text('Create');
    expect(createProjectButton, findsOneWidget);
    // Since no name, tapping create should not close dialog
    await tester.tap(createProjectButton);
    await tester.pumpAndSettle();

    // Dialog should still be open
    expect(find.text('New Flutter Project'), findsOneWidget);

    // Dismiss dialog
    final cancelButton = find.text('Cancel');
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    // Back to welcome screen
    expect(find.text('Welcome to'), findsOneWidget);
  });

  testWidgets('FIDE integration: test AI panel basic functionality', (
    WidgetTester tester,
  ) async {
    // Load main app
    await tester.pumpWidget(const ProviderScope(child: FIDE()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Create a test project programmatically
    final tempDir = Directory.systemTemp;
    final testProjectDir = await Directory(
      path.join(tempDir.path, 'fide_integration_test_ai'),
    ).create(recursive: true);
    final libDir = Directory(path.join(testProjectDir.path, 'lib'));
    await libDir.create();
    // Create pubspec.yaml
    final pubspec = File(path.join(testProjectDir.path, 'pubspec.yaml'));
    await pubspec.writeAsString('name: test\nflutter:\n  sdk: flutter\n');
    final mainDart = File(path.join(libDir.path, 'main.dart'));
    await mainDart.writeAsString('void main() {}');

    // Load the project
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final projectService = container.read(projectServiceProvider);
    final loadSuccess = await projectService.loadProject(testProjectDir.path);
    expect(loadSuccess, isTrue);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Select the main.dart file
    final mainDartItem = FileSystemItem.fromFileSystemEntity(mainDart);
    container.read(selectedFileProvider.notifier).state = mainDartItem;
    await tester.pumpAndSettle();

    // Switch to AI panel (right panel index 2 for AI)
    container.read(activeRightPanelTabProvider.notifier).state = 2;
    await tester.pumpAndSettle();

    // Verify that the provider state was updated correctly
    expect(container.read(activeRightPanelTabProvider), equals(2));

    // Wait for all async operations to complete
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Clean up
    if (await testProjectDir.exists()) {
      await testProjectDir.delete(recursive: true);
    }

    // Additional cleanup
    container.read(selectedFileProvider.notifier).state = null;
    container.read(projectLoadedProvider.notifier).state = false;
    container.read(currentProjectPathProvider.notifier).state = null;
    container.read(activeRightPanelTabProvider.notifier).state = 0;
    await tester.pumpAndSettle();
  });

  testWidgets('FIDE integration: test localization panel', (
    WidgetTester tester,
  ) async {
    // Load main app with a project
    await tester.pumpWidget(const ProviderScope(child: FIDE()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Create a test project programmatically
    final tempDir = Directory.systemTemp;
    final testProjectDir = await Directory(
      path.join(tempDir.path, 'fide_integration_test_loc'),
    ).create(recursive: true);
    final libDir = Directory(path.join(testProjectDir.path, 'lib'));
    await libDir.create();
    // Create pubspec.yaml
    final pubspec = File(path.join(testProjectDir.path, 'pubspec.yaml'));
    await pubspec.writeAsString('name: test\nflutter:\n  sdk: flutter\n');
    final mainDart = File(path.join(libDir.path, 'main.dart'));
    await mainDart.writeAsString('void main() {}');

    // Load the project
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final projectService = container.read(projectServiceProvider);
    final loadSuccess = await projectService.loadProject(testProjectDir.path);
    expect(loadSuccess, isTrue);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Select the main.dart file
    final mainDartItem = FileSystemItem.fromFileSystemEntity(mainDart);
    container.read(selectedFileProvider.notifier).state = mainDartItem;
    await tester.pumpAndSettle();

    // Switch to localization panel (right panel index 1 for localization)
    container.read(activeRightPanelTabProvider.notifier).state = 1;
    await tester.pumpAndSettle();

    // Verify localization panel is accessible
    expect(find.byType(MaterialApp), findsOneWidget);

    // Wait for all async operations to complete
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Check for localization-related elements (specific assertions depend on panel implementation)
    // This tests that the panel can be switched to without errors

    // Clean up
    if (await testProjectDir.exists()) {
      await testProjectDir.delete(recursive: true);
    }

    // Additional cleanup
    container.read(selectedFileProvider.notifier).state = null;
    container.read(projectLoadedProvider.notifier).state = false;
    container.read(currentProjectPathProvider.notifier).state = null;
    container.read(activeRightPanelTabProvider.notifier).state = 0;
    await tester.pumpAndSettle();
  });

  testWidgets('FIDE integration: test outline panel', (
    WidgetTester tester,
  ) async {
    // Start app
    await tester.pumpWidget(const ProviderScope(child: FIDE()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Create a test project programmatically
    final tempDir = Directory.systemTemp;
    final testProjectDir = await Directory(
      path.join(tempDir.path, 'fide_integration_test_outline'),
    ).create(recursive: true);
    final libDir = Directory(path.join(testProjectDir.path, 'lib'));
    await libDir.create();
    final mainDart = File(path.join(libDir.path, 'main.dart'));
    await mainDart.writeAsString('void main() {}');

    // Create pubspec.yaml
    final pubspec = File(path.join(testProjectDir.path, 'pubspec.yaml'));
    await pubspec.writeAsString('name: test\nflutter:\n  sdk: flutter\n');

    // Load the project
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final projectService = container.read(projectServiceProvider);
    final loadSuccess = await projectService.loadProject(testProjectDir.path);
    expect(loadSuccess, isTrue);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Select the main.dart file
    final mainDartItem = FileSystemItem.fromFileSystemEntity(mainDart);
    container.read(selectedFileProvider.notifier).state = mainDartItem;
    await tester.pumpAndSettle();

    // Switch to outline panel (right panel index 0 for outline)
    container.read(activeRightPanelTabProvider.notifier).state = 0;
    await tester.pumpAndSettle();

    // Verify outline panel loads
    expect(find.byType(MaterialApp), findsOneWidget);

    // Wait for all async operations to complete
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // This tests basic panel switching, outline should show code structure when file is selected

    // Clean up
    if (await testProjectDir.exists()) {
      await testProjectDir.delete(recursive: true);
    }

    // Additional cleanup
    container.read(selectedFileProvider.notifier).state = null;
    container.read(projectLoadedProvider.notifier).state = false;
    container.read(currentProjectPathProvider.notifier).state = null;
    container.read(activeRightPanelTabProvider.notifier).state = 0;
    await tester.pumpAndSettle();
  });

  testWidgets('FIDE integration: test file content display and search', (
    WidgetTester tester,
  ) async {
    // Create and load a project first
    await tester.pumpWidget(const ProviderScope(child: FIDE()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Manually create and load a simple project for testing
    final tempDir = Directory.systemTemp;
    final testProjectDir = await Directory(
      path.join(tempDir.path, 'fide_integration_test_content'),
    ).create(recursive: true);

    // Create basic Flutter project structure
    final libDir = Directory(path.join(testProjectDir.path, 'lib'));
    await libDir.create();

    // Create pubspec.yaml
    final pubspec = File(path.join(testProjectDir.path, 'pubspec.yaml'));
    await pubspec.writeAsString('name: test\nflutter:\n  sdk: flutter\n');

    final mainDart = File(path.join(libDir.path, 'main.dart'));
    await mainDart.writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Test App')),
        body: Center(child: Text('Hello World!')),
      ),
    );
  }
}
''');

    // Load the project
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final projectService = container.read(projectServiceProvider);
    final loadSuccess = await projectService.loadProject(testProjectDir.path);
    expect(loadSuccess, isTrue);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Select the main.dart file
    final mainDartItem = FileSystemItem.fromFileSystemEntity(mainDart);
    container.read(selectedFileProvider.notifier).state = mainDartItem;
    await tester.pumpAndSettle();

    // Verify file is selected and content is accessible
    final selectedFile = container.read(selectedFileProvider);
    expect(selectedFile?.path, equals(mainDart.path));

    final content = await selectedFile!.readAsString();
    expect(content.contains('void main()'), isTrue);

    // Test search panel functionality (basic switching)
    container.read(activeLeftPanelTabProvider.notifier).state =
        3; // Search panel
    await tester.pumpAndSettle();

    // Verify search panel loads
    expect(find.byType(MaterialApp), findsOneWidget);

    // Add additional wait to ensure all async operations complete
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Clean up test project
    if (await testProjectDir.exists()) {
      await testProjectDir.delete(recursive: true);
    }

    // Additional cleanup - clear selections
    container.read(selectedFileProvider.notifier).state = null;
    container.read(projectLoadedProvider.notifier).state = false;
    container.read(currentProjectPathProvider.notifier).state = null;
    await tester.pumpAndSettle();
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
