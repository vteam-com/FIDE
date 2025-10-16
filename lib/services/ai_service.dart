import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

class AIService {
  static const String _ollamaUrl = 'http://localhost:11434/api/generate';
  static const String _defaultModel =
      'codellama'; // Can be changed to other models like 'llama2', 'mistral', etc.

  Future<String> getCodeSuggestion(String prompt, String context) async {
    try {
      final fullPrompt =
          '''
You are a helpful coding assistant. Provide concise, accurate code suggestions.

Context: $context

Request: $prompt

Please provide a helpful response focused on the coding request.''';

      final response = await http
          .post(
            Uri.parse(_ollamaUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _defaultModel,
              'prompt': fullPrompt,
              'stream': false,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Timeout after 30 seconds to prevent hanging

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No suggestion available';
      } else {
        return 'Error: Failed to get AI suggestion (${response.statusCode}). Make sure Ollama is running with the $_defaultModel model.';
      }
    } catch (e) {
      return 'Error: $e\n\nMake sure Ollama is installed and running on localhost:11434';
    }
  }

  Future<String> explainCode(String code) async {
    return await getCodeSuggestion(
      'Explain what this code does in simple terms:',
      code,
    );
  }

  /// Gets the current Flutter SDK version by running flutter --version
  Future<String> _getFlutterSdkVersion() async {
    try {
      final result = await Process.run('flutter', ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();

        // Look for Dart SDK version in the output
        // Example output contains: "Dart 3.9.2 • DevTools 2.32.0"
        final dartVersionRegex = RegExp(r'Dart (\d+\.\d+\.\d+)');
        final match = dartVersionRegex.firstMatch(output);
        if (match != null) {
          final version = match.group(1)!;
          return '^$version'; // Return in pubspec format (^3.9.2)
        }
      }

      // Fallback to a reasonable default if detection fails
      return '^3.0.0';
    } catch (e) {
      // Fallback to default on error
      return '^3.0.0';
    }
  }

  Future<String> getAiPrompt(
    final String projectName,
    final String description,
  ) async {
    final prompt =
        '''
You are a professional Flutter developer.
Your task is to generate the **`lib/main.dart`** file for a Flutter app.
Follow these rules:

1. Output **only valid Dart and Flutter code** for lib/main.dart.
2. Provide the full `lib/main.dart` content including `import` statements.
3. Use Material 3 design and follow Flutter best practices.
4. Add inline comments explaining important parts of the code.
5. Structure the app properly (screens, widgets, state management if necessary).
6. Do not include pubspec.yaml or README.md content.
7. Do not write explanations outside of code files.
8. Do not include instructions or """ wrapper text.

Customer description:
"$description"
''';
    return prompt;
  }

  Future<Map<String, String>> generateProject(
    String projectName,
    String description,
  ) async {
    try {
      final prompt = await getAiPrompt(projectName, description);

      final response = await http
          .post(
            Uri.parse(_ollamaUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _defaultModel,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(
            const Duration(seconds: 60),
          ); // Timeout after 60 seconds to prevent hanging

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawResponse = data['response'] ?? '';

        // Parse the response - extract main.dart from code blocks
        final Map<String, String> files = {};

        // Create pubspec.yaml directly
        final sdkVersion = await _getFlutterSdkVersion();
        files['pubspec.yaml'] =
            '''
name: $projectName
description: Generated Flutter app with AI.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: $sdkVersion
  flutter: '>=3.0.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

''';

        // Create README.md directly
        files['README.md'] =
            '''
# $projectName

$description

## Getting Started

This Flutter app was generated with AI assistance.

### Running the app
1. Make sure you have Flutter installed
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app
4. For web support: `flutter run -d web-server` or `flutter run -d chrome`

## Project Structure
- `lib/main.dart`: Main application file
- `pubspec.yaml`: Dependencies and project configuration
''';

        // Extract Dart code (lib/main.dart) from AI response
        final dartBlockRegex = RegExp(
          r'```\s*(?:dart)?\s*\n?(.*?)\n?```',
          caseSensitive: false,
          dotAll: true,
        );
        final dartMatches = dartBlockRegex.allMatches(rawResponse);

        bool foundMainDart = false;
        if (dartMatches.isNotEmpty) {
          for (final match in dartMatches) {
            final dartContent = match.group(1)?.trim();
            if (dartContent != null &&
                dartContent.isNotEmpty &&
                (dartContent.contains('void main()') ||
                    dartContent.contains(
                      'import \'package:flutter/material.dart\'',
                    ))) {
              files['lib/main.dart'] = dartContent;
              foundMainDart = true;
              break; // Use the first valid Dart block
            }
          }
        }

        // Fallback: if no code blocks found, try extracting the entire response
        if (!foundMainDart) {
          String dartContent = rawResponse.trim();
          if (dartContent.contains(
                'import \'package:flutter/material.dart\'',
              ) ||
              dartContent.contains('void main()')) {
            files['lib/main.dart'] = dartContent;
            foundMainDart = true;
          }
        }

        // Last fallback: if nothing worked, return a basic main.dart
        if (!foundMainDart) {
          files['lib/main.dart'] =
              '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$projectName',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('$projectName'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$description',
            ),
          ],
        ),
      ),
    );
  }
}
''';
          foundMainDart = true;
        }

        // Validate we have the required files with content
        if (files.containsKey('pubspec.yaml') &&
            files.containsKey('lib/main.dart') &&
            files['pubspec.yaml']!.isNotEmpty &&
            files['lib/main.dart']!.isNotEmpty) {
          return files;
        } else {
          // Debug: show what we found
          print('🔍 Debug: Raw response length: ${rawResponse.length}');
          print(
            '🔍 Debug: Found pubspec.yaml: ${files['pubspec.yaml']?.length ?? 0} chars',
          );
          print(
            '🔍 Debug: Found main.dart: ${files['lib/main.dart']?.length ?? 0} chars',
          );
          print(
            '🔍 Debug: Response preview: ${rawResponse.substring(0, min(200, rawResponse.length))}',
          );

          return {
            'error':
                'Failed to extract project files from AI response. Expected valid pubspec.yaml and lib/main.dart code.',
          };
        }
      } else {
        return {
          'error':
              'Failed to get AI suggestion (${response.statusCode}). Make sure Ollama is running with the $_defaultModel model.',
        };
      }
    } catch (e) {
      return {
        'error':
            'Error: $e\n\nMake sure Ollama is installed and running on localhost:11434',
      };
    }
  }

  Future<String> generateCode(String description) async {
    return await getCodeSuggestion(
      'Generate Flutter/Dart code for the following requirement:',
      description,
    );
  }

  Future<String> refactorCode(String code, String instruction) async {
    return await getCodeSuggestion(
      'Refactor this code with the following instruction: $instruction',
      code,
    );
  }

  /// Checks if Ollama is installed on the system
  Future<bool> isOllamaInstalled() async {
    try {
      final whichResult = await Process.run('which', ['ollama']);
      return whichResult.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Checks if Ollama service is currently running
  Future<bool> isOllamaRunning() async {
    try {
      final listResult = await Process.run('ollama', ['list']);
      return listResult.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the required model (codellama) is downloaded
  Future<bool> isModelInstalled() async {
    try {
      final listResult = await Process.run('ollama', ['list']);
      if (listResult.exitCode == 0) {
        final models = listResult.stdout.toString();
        return models.contains(_defaultModel);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Installs Ollama using the official installation script
  Future<void> installOllama() async {
    if (Platform.isMacOS || Platform.isLinux) {
      // Install Ollama using the official install script
      final installResult = await Process.run('sh', [
        '-c',
        'curl -fsSL https://ollama.ai/install.sh | sh',
      ]);

      if (installResult.exitCode != 0) {
        throw Exception('Failed to install Ollama: ${installResult.stderr}');
      }

      // Pull the default model
      final pullResult = await Process.run('ollama', ['pull', _defaultModel]);
      if (pullResult.exitCode != 0) {
        throw Exception(
          'Failed to pull $_defaultModel model: ${pullResult.stderr}',
        );
      }
    } else if (Platform.isWindows) {
      throw Exception(
        'Please install Ollama manually from https://ollama.ai/download for Windows.',
      );
    } else {
      throw Exception('Unsupported platform. Please install Ollama manually.');
    }
  }

  /// Starts the Ollama service in the background
  Future<void> startOllama() async {
    // Start the Ollama background server
    await Process.start(
      'ollama',
      ['serve'],
      mode: ProcessStartMode
          .detached, // run independently from the current process
    );

    // Give it a moment to start up
    await Future.delayed(const Duration(seconds: 3));
  }

  /// Downloads the default model
  Future<void> downloadModel() async {
    final pullResult = await Process.run('ollama', ['pull', _defaultModel]);
    if (pullResult.exitCode != 0) {
      throw Exception(
        'Failed to download $_defaultModel model: ${pullResult.stderr}',
      );
    }
  }

  /// Ensures Ollama is running and ready for use
  Future<bool> ensureOllamaReady() async {
    try {
      // Check if Ollama is installed
      if (!await isOllamaInstalled()) {
        print('⚠️  Ollama not installed, attempting installation...');
        await installOllama();
        print('✅ Ollama installed successfully');
      }

      // Check if Ollama is running
      if (!await isOllamaRunning()) {
        print('🔄 Starting Ollama service...');
        await startOllama();
        if (!await isOllamaRunning()) {
          throw Exception('Failed to start Ollama service');
        }
        print('✅ Ollama service started');
      }

      // Check if model is installed
      if (!await isModelInstalled()) {
        print('📥 Downloading $_defaultModel model...');
        await downloadModel();
        print('✅ $_defaultModel model downloaded');
      }

      return true;
    } catch (e) {
      print('❌ Failed to ensure Ollama readiness: $e');
      return false;
    }
  }
}
