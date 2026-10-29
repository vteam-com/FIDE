// ignore: fcheck_dead_code
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/ollama_installer.dart';
import 'package:http/http.dart' as http;

part 'ai_service.ai_service_exception.dart';

/// Talks to the local Ollama model: code suggestions, explanations,
/// refactoring, and generating starter project files.
///
/// Failed requests throw an [AiServiceException].
class AIService {
  /// Constraint used when the installed Dart version can't be detected.
  static const String _fallbackDartConstraint = '^3.0.0';

  /// Host and port Ollama listens on by default.
  static const String ollamaHost = 'localhost:11434';

  /// Path of Ollama's one-shot generation endpoint.
  static const String _generatePath = '/api/generate';

  static const String _defaultModel = OllamaInstaller.model;

  final FlutterSdk _sdk;
  final http.Client _client;

  /// Creates an AI service that reads SDK versions from [_sdk] and sends
  /// requests through [client] (a fresh one by default).
  AIService([this._sdk = const FlutterSdk(), http.Client? client])
    : _client = client ?? http.Client();

  /// Sends [prompt] to the model and returns its response text, which may
  /// be empty.
  ///
  /// Throws an [AiServiceException] when Ollama can't be reached within
  /// [timeout] or answers with an error status.
  Future<String> _generate(String prompt, Duration timeout) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.http(ollamaHost, _generatePath),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _defaultModel,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(timeout);
    } catch (e) {
      throw AiServiceException(
        '$e\n\nMake sure Ollama is installed and running on $ollamaHost',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AiServiceException(
        'Failed to get AI response (${response.statusCode}). Make sure Ollama is running with the $_defaultModel model.',
      );
    }
    final data = jsonDecode(response.body);
    return data is Map ? data['response']?.toString() ?? '' : '';
  }

  /// Requests a coding suggestion from Ollama using prompt and contextual
  /// text; empty when the model has nothing to say.
  Future<String> getCodeSuggestion(String prompt, String context) {
    return _generate(
      '''
You are a helpful coding assistant. Provide concise, accurate code suggestions.

Context: $context

Request: $prompt

Please provide a helpful response focused on the coding request.''',
      AppDuration.aiSuggestionTimeout,
    );
  }

  /// Runs [action] on the user's [text]; [context] (the selected file's
  /// content) is only sent for [AiAction.ask].
  Future<String> respond(AiAction action, String text, String context) {
    return switch (action) {
      AiAction.ask => getCodeSuggestion(text, context),
      AiAction.explain => explainCode(text),
      AiAction.generate => generateCode(text),
      AiAction.refactor => refactorCode(text, 'Please refactor this code'),
    };
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

  /// Generates starter project files: `pubspec.yaml`, `README.md` and
  /// `lib/main.dart` (a basic app when the model's answer has no usable
  /// code).
  ///
  /// Throws an [AiServiceException] when the request fails.
  Future<Map<String, String>> generateProject(
    String projectName,
    String description,
  ) async {
    final rawResponse = await _generate(
      await getAiPrompt(projectName, description),
      AppDuration.aiGenerateTimeout,
    );

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
      if (dartContent.contains('import \'package:flutter/material.dart\'') ||
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
    }

    return files;
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
