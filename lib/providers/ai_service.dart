// ignore: fcheck_dead_code
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:http/http.dart' as http;

/// Represents `AIService`.
class AIService {
  /// Constraint used when the installed Dart version can't be detected.
  static const String _fallbackDartConstraint = '^3.0.0';
  final FlutterSdk _sdk;

  /// Creates an AI service that reads SDK versions from [_sdk].
  const AIService([this._sdk = const FlutterSdk()]);

  static const String _ollamaUrl = 'http://localhost:11434/api/generate';
  static const String _defaultModel = OllamaInstaller.model;

  /// Requests a coding suggestion from Ollama using prompt and contextual text.
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
            AppDuration.aiSuggestionTimeout,
          ); // Timeout after 30 seconds to prevent hanging

      if (response.statusCode == HttpStatus.ok) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No suggestion available';
      } else {
        return 'Error: Failed to get AI suggestion (${response.statusCode}). Make sure Ollama is running with the $_defaultModel model.';
      }
    } catch (e) {
      return 'Error: $e\n\nMake sure Ollama is installed and running on localhost:11434';
    }
  }

  /// Requests a plain-language explanation for the provided source code.
  Future<String> explainCode(String code) async {
    return await getCodeSuggestion(
      'Explain what this code does in simple terms:',
      code,
    );
  }

  /// Dart SDK constraint matching the installed Flutter, for generated pubspecs.
  Future<String> _getFlutterSdkVersion() async {
    final dartVersion = (await _sdk.versions())?.dart;
    // Pubspec constraint format, e.g. ^3.9.2
    return dartVersion == null ? _fallbackDartConstraint : '^$dartVersion';
  }

  /// Builds the AI prompt used to generate an initial Flutter project file.
  Future<String> getAiPrompt(String projectName, String description) async {
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

  /// Generates starter project files (including `pubspec.yaml` and `lib/main.dart`).
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
            AppDuration.aiGenerateTimeout,
          ); // Timeout after 60 seconds to prevent hanging

      if (response.statusCode == HttpStatus.ok) {
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
            '🔍 Debug: Response preview: ${rawResponse.substring(0, min(AppMetric.logPreviewChars, rawResponse.length))}',
          );

          return {
            'error': 'Failed to extract project files from AI response. Expected valid pubspec.yaml and lib/main.dart code.',
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

  /// Generates code for a requirement by delegating to the suggestion endpoint.
  Future<String> generateCode(String description) async {
    return await getCodeSuggestion(
      'Generate Flutter/Dart code for the following requirement:',
      description,
    );
  }

  /// Refactors code according to a natural-language instruction.
  Future<String> refactorCode(String code, String instruction) async {
    return await getCodeSuggestion(
      'Refactor this code with the following instruction: $instruction',
      code,
    );
  }
}
