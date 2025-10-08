import 'dart:convert';
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

      final response = await http.post(
        Uri.parse(_ollamaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _defaultModel,
          'prompt': fullPrompt,
          'stream': false,
        }),
      );

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

  Future<Map<String, String>> generateProject(
    String projectName,
    String description,
  ) async {
    try {
      final prompt =
          '''## Task

Generate a complete Flutter project that implements: $description

## Output format

1. The response must contain **exactly three** code blocks, one for each file.
2. Each code block must be fenced with ``` followed by the language identifier (`yaml`, `dart`, `md`).
3. Do **not** include any explanatory text or comments outside the fences.
4. The first block must be the `pubspec.yaml` (with a minimal dependency list for a basic Flutter app).
5. The second block must be `lib/main.dart` that contains a `main()` function and the UI code implementing the described feature.
6. The third block must be a `README.md` that explains how to run the project.

## Example

**Prompt**: "Build a simple counter app in Flutter."

**Response**:
```yaml
name: counter_app
description: A simple counter app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text('\$_counter', style: Theme.of(context).textTheme.headlineMedium),
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
```
```md
# Counter App

A simple Flutter counter application.

## Getting Started

1. Make sure you have Flutter installed and configured
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

The app displays a counter that increments when the floating action button is pressed.

**Now generate the code for the requested task:** Generate a Flutter app called "$projectName" that $description
          ''';

      final response = await http.post(
        Uri.parse(_ollamaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _defaultModel,
          'prompt': prompt,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawResponse = data['response'] ?? '';

        // Parse the response to extract the three code blocks
        final Map<String, String> files = {};
        final regex = RegExp(r'```\w*\s*(.*?)\s*```', dotAll: true);
        final matches = regex.allMatches(rawResponse);

        if (matches.length >= 3) {
          final codeBlocks = matches.take(3).toList();
          // Extract pubspec.yaml
          final pubspecContent =
              codeBlocks[0].group(1)?.replaceFirst(RegExp(r'^yaml\s*'), '') ??
              '';
          files['pubspec.yaml'] = pubspecContent.trim();

          // Extract main.dart
          final mainDartContent =
              codeBlocks[1].group(1)?.replaceFirst(RegExp(r'^dart\s*'), '') ??
              '';
          files['lib/main.dart'] = mainDartContent.trim();

          // Extract README.md
          final readmeContent =
              codeBlocks[2].group(1)?.replaceFirst(RegExp(r'^md\s*'), '') ?? '';
          files['README.md'] = readmeContent.trim();

          return files;
        } else {
          return {
            'error': 'Invalid AI response format - expected 3 code blocks',
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
}
