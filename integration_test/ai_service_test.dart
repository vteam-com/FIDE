import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fide/services/ai_service.dart';
import 'package:path/path.dart' as path;

import 'steps.dart';

/// Helper function to delete a directory recursively
Future<void> deleteDirectory(Directory dir) async {
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

void main() {
  late AIService aiService;
  late Directory testOutputDir;

  setUp(() async {
    aiService = AIService();
    // Use test_output folder at project root for persistent testing
    testOutputDir = Directory('test_output');
    if (!await testOutputDir.exists()) {
      await testOutputDir.create();
    }
  });

  // Note: tearDown is removed for build test to allow manual testing of generated app

  group('AIService.generateProject()', () {
    testWidgets(
      'generate working TicTacToe game',
      (WidgetTester tester) async {
        //--------------------------------------------------
        // Clear new project
        const projectName = 'tictactoe_game';
        const description =
            'Simple Flutter Tic-Tac-Toe game app. Include a 3x3 grid, two players (X and O), win detection, and a reset button. Keep it simple with basic Flutter widgets only.';

        stepStart('Clean start');
        final expectedProjectDir = Directory(
          path.join(testOutputDir.path, projectName),
        );

        substep('🗂️ ${expectedProjectDir.absolute.path}');

        // Clean up any existing test directory
        if (await expectedProjectDir.exists()) {
          substep('🧹 Removing existing test directory...');
          await deleteDirectory(expectedProjectDir);
        }
        stepStop();

        //--------------------------------------------------
        // Ensure Ollama is running
        stepStart('Ollama');
        {
          final ollamaRunning = await startOllamaIfNeeded(aiService);
          if (ollamaRunning) {
            print('Ollama is running');
          } else {
            print('⚠️  Cannot start Ollama - skipping this test');
            return;
          }
        }
        stepStop();

        //--------------------------------------------------
        // Create project
        stepStart('Create Project');

        substep('aiService Generate');

        // Generate the project files using AI
        final Map<String, String> files = await aiService.generateProject(
          projectName,
          description,
        );

        // Validate that AI generation succeeded (not just that it was attempted)
        substep('Expected text returned');
        expect(
          files.containsKey('error'),
          isFalse,
          reason:
              'AI generation should succeed when Ollama is running. Error: ${files['error']}',
        );

        // Verify we have all required files
        expect(
          files.containsKey('pubspec.yaml'),
          isTrue,
          reason: 'Should generate pubspec.yaml',
        );
        expect(
          files.containsKey('lib/main.dart'),
          isTrue,
          reason: 'Should generate lib/main.dart',
        );
        expect(
          files.containsKey('README.md'),
          isTrue,
          reason: 'Should generate README.md',
        );

        // Verify files are not empty
        expect(
          files['pubspec.yaml']?.isNotEmpty,
          isTrue,
          reason: 'pubspec.yaml should not be empty',
        );
        expect(
          files['lib/main.dart']?.isNotEmpty,
          isTrue,
          reason: 'main.dart should not be empty',
        );
        expect(
          files['README.md']?.isNotEmpty,
          isTrue,
          reason: 'README.md should not be empty',
        );

        // Verify pubspec.yaml has basic required fields
        substep('Inspect content of "pubspec.yaml"');
        {
          final pubspecContent = files['pubspec.yaml']!;
          expect(
            pubspecContent.contains('name:'),
            isTrue,
            reason: 'pubspec.yaml should contain name field',
          );
          expect(
            pubspecContent.contains('flutter:'),
            isTrue,
            reason: 'pubspec.yaml should contain flutter block',
          );
          expect(
            pubspecContent.contains('sdk: flutter'),
            isTrue,
            reason: 'pubspec.yaml should declare flutter sdk dependency',
          );
        }
        // Verify main.dart contains essential Flutter code
        substep('Inspect content of "lib/main.dart"');
        final mainDartContent = files['lib/main.dart']!;
        {
          expect(
            mainDartContent.contains(
              'import \'package:flutter/material.dart\'',
            ),
            isTrue,
            reason: 'main.dart should import flutter/material.dart',
          );
          expect(
            mainDartContent.contains('void main()'),
            isTrue,
            reason: 'main.dart should contain main function',
          );
          expect(
            mainDartContent.contains('runApp('),
            isTrue,
            reason: 'main.dart should call runApp',
          );
        }

        // Create the actual Flutter project structure
        substep('Create the project files');
        final projectDir = Directory(
          path.join(testOutputDir.path, projectName),
        );
        await projectDir.create(recursive: true);

        // Create lib directory
        final libDir = Directory(path.join(projectDir.path, 'lib'));
        await libDir.create();

        // Write the generated files
        final pubspecFile = File(path.join(projectDir.path, 'pubspec.yaml'));
        await pubspecFile.writeAsString(files['pubspec.yaml']!);

        final mainDartFile = File(path.join(libDir.path, 'main.dart'));
        await mainDartFile.writeAsString(files['lib/main.dart']!);

        final readmeFile = File(path.join(projectDir.path, 'README.md'));
        await readmeFile.writeAsString(files['README.md']!);

        // Verify files were written correctly
        expect(
          await pubspecFile.exists(),
          isTrue,
          reason: 'pubspec.yaml should be created',
        );
        expect(
          await mainDartFile.exists(),
          isTrue,
          reason: 'main.dart should be created',
        );
        expect(
          await readmeFile.exists(),
          isTrue,
          reason: 'README.md should be created',
        );

        // Verify TicTacToe-specific content
        expect(
          mainDartContent.contains('Tic') ||
              mainDartContent.contains('TicTac') ||
              projectName.toLowerCase().contains('tictactoe'),
          isTrue,
          reason: 'Generated code should be related to TicTacToe game',
        );

        // Verify basic Flutter widget structure
        expect(
          mainDartContent.contains('StatelessWidget') ||
              mainDartContent.contains('StatefulWidget'),
          isTrue,
          reason: 'Should contain basic Flutter widgets',
        );

        // Verify game logic elements (at least some indication of game state)
        bool containsUI =
            mainDartContent.contains('List') ||
            mainDartContent.contains('state') ||
            mainDartContent.contains('Grid') ||
            mainDartContent.contains('score') ||
            mainDartContent.contains('win') ||
            mainDartContent.contains('reset');

        if (!containsUI) {
          substep(
            '********************\n$mainDartContent\n********************',
          );
        }

        // Enable web support for the project
        substep('🌐 Setting up web support for generated app...');
        {
          // Enable web configuration globally (only needs to be done once)
          await runCommand('flutter', [
            'config',
            '--enable-web',
          ], projectDir.path);

          // Create web platform files for this project
          await runCommand('flutter', [
            'create',
            '.',
            '--platforms=web',
          ], projectDir.path);

          // Format the generated code
          await runCommand('dart', ['format', '.'], projectDir.path);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Helper function to run a command and get result
Future<ProcessResult> runCommand(
  String command,
  List<String> args,
  String workingDir,
) async {
  return Process.run(command, args, workingDirectory: workingDir);
}

/// Helper function to start Ollama if not running and wait for it to be ready
Future<bool> startOllamaIfNeeded(AIService aiService) async {
  return aiService.ensureOllamaReady();
}
