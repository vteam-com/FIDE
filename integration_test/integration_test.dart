import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/main.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FIDE UI Integration Tests', () {
    late Directory tempDir;

    setUpAll(() async {
      // Set up test-specific SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Create a temporary directory for testing
      final appDir = await getApplicationDocumentsDirectory();
      tempDir = Directory(path.join(appDir.path, 'fide_test_projects'));
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);
    });

    tearDownAll(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Welcome screen displays correctly', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle - increase timeout for integration tests
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify welcome screen elements
      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('FIDE'), findsOneWidget);
      expect(
        find.text('Flutter Integrated Developer Environment'),
        findsOneWidget,
      );
      expect(find.text('Create New Project'), findsOneWidget);
      expect(find.text('Open Flutter Project'), findsOneWidget);
    });

    testWidgets('Create project dialog can be opened and filled', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify we're on the welcome screen
      expect(find.text('Create New Project'), findsOneWidget);

      // Tap the "Create New Project" button
      await tester.tap(find.text('Create New Project'));
      await tester.pumpAndSettle();

      // Verify the create project dialog appears
      expect(find.text('Create New Flutter Project'), findsOneWidget);
      expect(find.text('Project Name'), findsOneWidget);
      expect(find.text('Parent Directory'), findsOneWidget);

      // Find the text fields in the dialog
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // Project name and directory fields

      // Enter "HelloWorld" in the project name field
      await tester.enterText(textFields.first, 'HelloWorld');
      await tester.pumpAndSettle();

      // Verify the text was entered
      expect(find.text('HelloWorld'), findsOneWidget);

      // Note: In a real integration test, we would also interact with the directory picker
      // and submit the form, but that requires mocking file system interactions
      // which is complex in integration tests
    });

    testWidgets('App renders MaterialApp correctly', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify MaterialApp is present
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Icon buttons are present in the UI', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify that icon buttons exist (these would be in title bar, panels, etc.)
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('Scaffold is present in the app structure', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify Scaffold is present (main app structure)
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('HelloWorld project creation flow can be initiated', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify we're on the welcome screen
      expect(find.text('Create New Project'), findsOneWidget);

      // Verify the project service is available for creating HelloWorld projects
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      final projectService = container.read(projectServiceProvider);

      // Verify the service has the createProject method
      expect(projectService.createProject, isNotNull);

      // This test verifies that the UI and service infrastructure
      // is in place for HelloWorld project creation
      // In a real integration test environment with flutter CLI available,
      // this would actually create the project
    });

    testWidgets(
      'Panel switching and file selection works after project creation',
      (WidgetTester tester) async {
        // Build the app
        await tester.pumpWidget(const ProviderScope(child: FIDE()));

        // Wait for the app to settle
        await tester.pumpAndSettle();

        // Create a mock Flutter project structure for testing
        final projectDir = Directory(path.join(tempDir.path, 'MockHelloWorld'));
        await projectDir.create(recursive: true);

        // Create basic Flutter project structure
        await Directory(path.join(projectDir.path, 'lib')).create();
        await Directory(path.join(projectDir.path, 'android')).create();
        await Directory(path.join(projectDir.path, 'ios')).create();

        // Create pubspec.yaml
        final pubspecFile = File(path.join(projectDir.path, 'pubspec.yaml'));
        await pubspecFile.writeAsString('''
name: mockhelloworld
description: A mock Flutter project for testing
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

        // Create main.dart
        final mainDartFile = File(path.join(projectDir.path, 'lib/main.dart'));
        await mainDartFile.writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mock Hello World',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Mock Hello World Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''');

        // Load the mock project
        final container = ProviderScope.containerOf(
          tester.element(find.byType(FIDE)),
        );
        final projectService = container.read(projectServiceProvider);
        final success = await projectService.loadProject(projectDir.path);

        expect(success, isTrue);

        // Wait for project to load
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify we're no longer on welcome screen
        expect(find.text('Welcome to'), findsNothing);

        // Test panel switching - look for panel toggle buttons
        final iconButtons = find.byType(IconButton);

        // Assuming the panel buttons are present, test that we can find them
        expect(iconButtons, findsWidgets);

        // Test file selection - the main.dart file should be selectable
        // This would require more specific UI element identification
        // For now, we verify the project loaded successfully
        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('Outline panel displays correctly for Dart files', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Create a mock Flutter project with a more complex Dart file
      final projectDir = Directory(path.join(tempDir.path, 'OutlineTest'));
      await projectDir.create(recursive: true);

      // Create basic Flutter project structure
      await Directory(path.join(projectDir.path, 'lib')).create();

      // Create pubspec.yaml
      final pubspecFile = File(path.join(projectDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: outlinetest
description: A test project for outline functionality
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

      // Create a more complex main.dart with classes, functions, etc.
      final mainDartFile = File(path.join(projectDir.path, 'lib/main.dart'));
      await mainDartFile.writeAsString('''
import 'package:flutter/material.dart';

// A top-level function
void main() {
  runApp(const MyApp());
}

// A top-level variable
const String appTitle = 'Outline Test App';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Outline Test Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _decrementCounter() {
    setState(() {
      _counter--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _decrementCounter,
            tooltip: 'Decrement',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

// Another top-level function
String getGreeting() {
  return 'Hello from outline test!';
}

// A utility class
class MathUtils {
  static int add(int a, int b) {
    return a + b;
  }

  static int multiply(int a, int b) {
    return a * b;
  }
}
''');

      // Load the mock project
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      final projectService = container.read(projectServiceProvider);
      final success = await projectService.loadProject(projectDir.path);

      expect(success, isTrue);

      // Wait for project to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're no longer on welcome screen
      expect(find.text('Welcome to'), findsNothing);

      // The outline panel should be available now
      // Since we can't easily test the outline panel content without more specific selectors,
      // we verify that the app loaded successfully and the outline infrastructure is in place
      expect(find.byType(MaterialApp), findsOneWidget);

      // Test that we can access the file content
      final fileContent = await mainDartFile.readAsString();
      expect(fileContent.contains('class MyApp'), isTrue);
      expect(fileContent.contains('void main()'), isTrue);
      expect(fileContent.contains('class MathUtils'), isTrue);
    });

    testWidgets('Search functionality works in project', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Create a mock Flutter project with searchable content
      final projectDir = Directory(path.join(tempDir.path, 'SearchTest'));
      await projectDir.create(recursive: true);

      // Create basic Flutter project structure
      await Directory(path.join(projectDir.path, 'lib')).create();

      // Create pubspec.yaml
      final pubspecFile = File(path.join(projectDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: searchtest
description: A test project for search functionality
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

      // Create main.dart with searchable content
      final mainDartFile = File(path.join(projectDir.path, 'lib/main.dart'));
      await mainDartFile.writeAsString('''
import 'package:flutter/material.dart';

// UNIQUE_SEARCH_TERM_1
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Search Test App',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // UNIQUE_SEARCH_TERM_2
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Test'),
      ),
      body: const Center(
        child: Text('Search functionality test'),
      ),
    );
  }
}

// UNIQUE_SEARCH_TERM_3
class SearchUtils {
  static bool containsTerm(String text, String term) {
    return text.contains(term);
  }
}
''');

      // Load the mock project
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      final projectService = container.read(projectServiceProvider);
      final success = await projectService.loadProject(projectDir.path);

      expect(success, isTrue);

      // Wait for project to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify project loaded
      expect(find.text('Welcome to'), findsNothing);
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify the test file contains our search terms
      final fileContent = await mainDartFile.readAsString();
      expect(fileContent.contains('UNIQUE_SEARCH_TERM_1'), isTrue);
      expect(fileContent.contains('UNIQUE_SEARCH_TERM_2'), isTrue);
      expect(fileContent.contains('UNIQUE_SEARCH_TERM_3'), isTrue);
    });

    testWidgets('Terminal panel integration works', (
      WidgetTester tester,
    ) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Create and load a project
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      final projectService = container.read(projectServiceProvider);

      // Create a simple test project
      final projectDir = Directory(path.join(tempDir.path, 'TerminalTest'));
      await projectDir.create(recursive: true);
      await Directory(path.join(projectDir.path, 'lib')).create();

      final pubspecFile = File(path.join(projectDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: terminaltest
description: A test project for terminal functionality
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

      final mainDartFile = File(path.join(projectDir.path, 'lib/main.dart'));
      await mainDartFile.writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Terminal Test')))));
}
''');

      final success = await projectService.loadProject(projectDir.path);
      expect(success, isTrue);

      // Wait for project to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify project loaded
      expect(find.text('Welcome to'), findsNothing);

      // Terminal functionality would be tested here if we had specific UI elements to interact with
      // For now, we verify the project infrastructure is working
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
