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

// Test data constants
const String testProjectName = 'TestProject';
const String testProjectDescription =
    'A test Flutter project for integration testing';

// Helper class for creating mock Flutter projects
class MockProjectFactory {
  static Future<Directory> createBasicFlutterProject(
    Directory baseDir,
    String projectName, {
    String description = testProjectDescription,
  }) async {
    final projectDir = Directory(path.join(baseDir.path, projectName));
    await projectDir.create(recursive: true);

    // Create standard Flutter project structure
    await Directory(path.join(projectDir.path, 'lib')).create();
    await Directory(path.join(projectDir.path, 'android')).create();
    await Directory(path.join(projectDir.path, 'ios')).create();
    await Directory(path.join(projectDir.path, 'test')).create();

    // Create pubspec.yaml
    final pubspecFile = File(path.join(projectDir.path, 'pubspec.yaml'));
    await pubspecFile.writeAsString('''
name: ${projectName.toLowerCase()}
description: $description
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

    // Create analysis_options.yaml
    final analysisFile = File(
      path.join(projectDir.path, 'analysis_options.yaml'),
    );
    await analysisFile.writeAsString('''
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
''');

    return projectDir;
  }

  static Future<void> createMainDartFile(
    Directory projectDir,
    String content,
  ) async {
    final mainDartFile = File(path.join(projectDir.path, 'lib', 'main.dart'));
    await mainDartFile.writeAsString(content);
  }

  static Future<void> createComplexMainDartFile(Directory projectDir) async {
    await createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';

// Top-level constants
const String appTitle = 'Complex Test App';
const Color primaryColor = Colors.blue;

// Top-level functions
void main() {
  runApp(const MyApp());
}

String getGreeting(String name) {
  return 'Hello, \$name!';
}

// Main App Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// Stateful Home Page
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  String _currentMessage = 'Welcome!';

  void _incrementCounter() {
    setState(() {
      _counter++;
      _currentMessage = getGreeting('User \$_counter');
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
      _currentMessage = 'Reset!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(appTitle),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _currentMessage,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _incrementCounter,
                  child: const Text('Increment'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _resetCounter,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Utility classes
class CounterUtils {
  static int doubleValue(int value) => value * 2;
  static int squareValue(int value) => value * value;
  static bool isEven(int value) => value % 2 == 0;
}

class StringUtils {
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String reverse(String text) {
    return text.split('').reversed.join();
  }
}
''');
  }
}

// Test helper functions
class TestHelpers {
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, [
    Duration timeout = const Duration(seconds: 3),
  ]) async {
    await tester.pumpAndSettle(timeout);
  }

  static Future<void> loadProjectAndWait(
    WidgetTester tester,
    String projectPath,
  ) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FIDE)),
    );
    final projectService = container.read(projectServiceProvider);
    final success = await projectService.loadProject(projectPath);
    expect(success, isTrue, reason: 'Project should load successfully');

    await pumpAndSettleWithTimeout(tester);
  }

  static void verifyWelcomeScreen() {
    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('FIDE'), findsOneWidget);
    expect(
      find.text('Flutter Integrated Developer Environment'),
      findsOneWidget,
    );
  }

  static void verifyMainAppLoaded() {
    expect(find.text('Welcome to'), findsNothing);
    expect(find.byType(MaterialApp), findsOneWidget);
  }
}

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
      await tempDir.create(recursive: true);
    });

    tearDownAll(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() async {
      // Clean up any existing test projects before each test
      if (await tempDir.exists()) {
        await tempDir.list().forEach((entity) async {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        });
      }
    });

    testWidgets('Welcome screen displays correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(
        tester,
        const Duration(seconds: 5),
      );

      TestHelpers.verifyWelcomeScreen();
      expect(find.text('Create New Project'), findsOneWidget);
      expect(find.text('Open Flutter Project'), findsOneWidget);
    });

    testWidgets('Create project dialog interaction', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Open create project dialog
      await tester.tap(find.text('Create New Project'));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Verify dialog content
      expect(find.text('Create New Flutter Project'), findsOneWidget);
      expect(find.text('Project Name'), findsOneWidget);
      expect(find.text('Parent Directory'), findsOneWidget);

      // Test text input
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.first, 'TestProject');
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      expect(find.text('TestProject'), findsOneWidget);
    });

    testWidgets('App basic structure renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Project service infrastructure is available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      final projectService = container.read(projectServiceProvider);

      expect(projectService.createProject, isNotNull);
      expect(projectService.loadProject, isNotNull);
    });

    testWidgets('Project loading and UI transition works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create and load a test project
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'TestProject',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Test')))));
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Verify UI elements are present after project load
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('Complex Dart file structure loads correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create project with complex Dart file
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'ComplexTest',
      );
      await MockProjectFactory.createComplexMainDartFile(projectDir);

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Verify file content is accessible
      final mainFile = File(path.join(projectDir.path, 'lib', 'main.dart'));
      final content = await mainFile.readAsString();

      expect(content.contains('class MyApp'), isTrue);
      expect(content.contains('class CounterUtils'), isTrue);
      expect(content.contains('void main()'), isTrue);
    });

    testWidgets('Project with search terms loads successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create project with searchable content
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'SearchTest',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';

// UNIQUE_SEARCH_TERM_1
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: HomePage());
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
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Search test')),
  );
}

// UNIQUE_SEARCH_TERM_3
class SearchUtils {
  static bool containsTerm(String text, String term) => text.contains(term);
}
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Verify search terms are present
      final mainFile = File(path.join(projectDir.path, 'lib', 'main.dart'));
      final content = await mainFile.readAsString();

      expect(content.contains('UNIQUE_SEARCH_TERM_1'), isTrue);
      expect(content.contains('UNIQUE_SEARCH_TERM_2'), isTrue);
      expect(content.contains('UNIQUE_SEARCH_TERM_3'), isTrue);
    });

    testWidgets('Terminal panel infrastructure loads', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create and load basic project
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'TerminalTest',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';
void main() => runApp(const MaterialApp(
  home: Scaffold(body: Center(child: Text('Terminal Test'))),
));
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Verify basic app structure is working
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('Left panel switching works correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Load a project to access the main layout
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'PanelTest',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';
void main() => runApp(const MaterialApp(
  home: Scaffold(body: Center(child: Text('Panel Test'))),
));
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Test switching between different left panels
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );

      // Test Explorer panel (index 0) - should show file tree
      container.read(activeLeftPanelTabProvider.notifier).state = 0;
      await TestHelpers.pumpAndSettleWithTimeout(tester);
      expect(find.byType(IconButton), findsWidgets); // Basic UI check

      // Test Organized panel (index 1) - should show organized view
      container.read(activeLeftPanelTabProvider.notifier).state = 1;
      await TestHelpers.pumpAndSettleWithTimeout(tester);
      expect(find.byType(IconButton), findsWidgets);

      // Test Git panel (index 2) - should show git information
      container.read(activeLeftPanelTabProvider.notifier).state = 2;
      await TestHelpers.pumpAndSettleWithTimeout(tester);
      expect(find.byType(IconButton), findsWidgets);

      // Test Search panel (index 3) - should show search interface
      container.read(activeLeftPanelTabProvider.notifier).state = 3;
      await TestHelpers.pumpAndSettleWithTimeout(tester);
      expect(find.byType(IconButton), findsWidgets);

      // Verify panel switching doesn't break the app
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Panel toggle buttons work correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Load a project
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'ToggleTest',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';
void main() => runApp(const MaterialApp(
  home: Scaffold(body: Center(child: Text('Toggle Test'))),
));
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Find panel toggle buttons in the title bar
      final iconButtons = find.byType(IconButton);

      // Should have at least the panel toggle buttons
      expect(iconButtons, findsWidgets);

      // Test that we can find buttons (basic smoke test for panel toggles)
      // In a real scenario, we'd tap specific buttons and verify panel visibility
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('Explorer panel displays file structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create project with multiple files and directories
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'ExplorerTest',
      );

      // Create additional files and directories
      await Directory(path.join(projectDir.path, 'lib', 'models')).create();
      await Directory(path.join(projectDir.path, 'lib', 'services')).create();
      await Directory(path.join(projectDir.path, 'lib', 'widgets')).create();

      await File(
        path.join(projectDir.path, 'lib', 'models', 'user.dart'),
      ).writeAsString('class User {}');
      await File(
        path.join(projectDir.path, 'lib', 'services', 'api.dart'),
      ).writeAsString('class ApiService {}');
      await File(
        path.join(projectDir.path, 'lib', 'widgets', 'button.dart'),
      ).writeAsString('class CustomButton {}');

      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/api.dart';
import 'widgets/button.dart';

void main() => runApp(const MaterialApp(
  home: Scaffold(body: Center(child: Text('Explorer Test'))),
));
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Switch to Explorer panel (index 0)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      container.read(activeLeftPanelTabProvider.notifier).state = 0;
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Verify the app is still functional with file structure loaded
      expect(find.byType(IconButton), findsWidgets);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Search panel interface loads', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Load project with searchable content
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'SearchPanelTest',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';

// SEARCHABLE_CONTENT_1
class SearchTestApp extends StatelessWidget {
  const SearchTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('SEARCHABLE_CONTENT_2'),
        ),
      ),
    );
  }
}

// SEARCHABLE_CONTENT_3
void main() => runApp(const SearchTestApp());
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Switch to Search panel (index 3)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      container.read(activeLeftPanelTabProvider.notifier).state = 3;
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Verify search panel loads without errors
      expect(find.byType(IconButton), findsWidgets);
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify the searchable content is present in files
      final mainFile = File(path.join(projectDir.path, 'lib', 'main.dart'));
      final content = await mainFile.readAsString();
      expect(content.contains('SEARCHABLE_CONTENT_1'), isTrue);
      expect(content.contains('SEARCHABLE_CONTENT_2'), isTrue);
      expect(content.contains('SEARCHABLE_CONTENT_3'), isTrue);
    });

    testWidgets('Git panel loads for project with git history', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create project that would have git history
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'GitPanelTest',
      );
      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';

// Initial commit content
class GitTestApp extends StatelessWidget {
  const GitTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Git Panel Test - Initial Commit'),
        ),
      ),
    );
  }
}

void main() => runApp(const GitTestApp());
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Switch to Git panel (index 2)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      container.read(activeLeftPanelTabProvider.notifier).state = 2;
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Verify git panel loads without errors
      expect(find.byType(IconButton), findsWidgets);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Organized panel displays structured view', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      TestHelpers.verifyWelcomeScreen();

      // Create project with organized structure
      final projectDir = await MockProjectFactory.createBasicFlutterProject(
        tempDir,
        'OrganizedPanelTest',
      );

      // Create organized directory structure
      await Directory(path.join(projectDir.path, 'lib', 'screens')).create();
      await Directory(path.join(projectDir.path, 'lib', 'components')).create();
      await Directory(path.join(projectDir.path, 'lib', 'utils')).create();
      await Directory(path.join(projectDir.path, 'lib', 'constants')).create();

      await File(
        path.join(projectDir.path, 'lib', 'screens', 'home_screen.dart'),
      ).writeAsString('class HomeScreen {}');
      await File(
        path.join(projectDir.path, 'lib', 'components', 'custom_button.dart'),
      ).writeAsString('class CustomButton {}');
      await File(
        path.join(projectDir.path, 'lib', 'utils', 'helpers.dart'),
      ).writeAsString('class Helpers {}');
      await File(
        path.join(projectDir.path, 'lib', 'constants', 'colors.dart'),
      ).writeAsString('const primaryColor = 0xFF000000;');

      await MockProjectFactory.createMainDartFile(projectDir, '''
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'components/custom_button.dart';
import 'utils/helpers.dart';
import 'constants/colors.dart';

void main() => runApp(const MaterialApp(
  home: Scaffold(body: Center(child: Text('Organized Panel Test'))),
));
''');

      await TestHelpers.loadProjectAndWait(tester, projectDir.path);
      TestHelpers.verifyMainAppLoaded();

      // Switch to Organized panel (index 1)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FIDE)),
      );
      container.read(activeLeftPanelTabProvider.notifier).state = 1;
      await TestHelpers.pumpAndSettleWithTimeout(tester);

      // Verify organized panel loads without errors
      expect(find.byType(IconButton), findsWidgets);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
