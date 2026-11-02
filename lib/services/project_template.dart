import 'dart:convert';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/flutter_sdk.dart';

/// Scaffolds a new project's starter files: `pubspec.yaml` and `README.md`
/// from templates, and `lib/main.dart` written by the model, or a basic
/// app when its answer has no usable code.
class ProjectTemplate {
  /// Constraint used when the installed Dart version can't be detected.
  static const String _fallbackDartConstraint = '^3.0.0';

  /// Fenced code blocks of a reply, optionally tagged `dart`.
  static final RegExp _codeBlock = RegExp(
    r'```\s*(?:dart)?\s*\n?(.*?)\n?```',
    caseSensitive: false,
    dotAll: true,
  );

  /// Runs of line breaks, folded away in one-line fields.
  static final RegExp _lineBreaks = RegExp(r'[\r\n]+');

  /// Import every Flutter `main.dart` starts with.
  static const String _materialImport =
      "import 'package:flutter/material.dart'";

  /// Entry point every `main.dart` declares.
  static const String _mainFunction = 'void main()';

  final ChatModel _model;
  final FlutterSdk _sdk;

  /// Creates a template asking [_model] for the code and reading the Dart
  /// version from [_sdk].
  const ProjectTemplate(this._model, this._sdk);

  /// Generates the starter files of the project [projectName] described by
  /// [description], by path relative to the project root; [cancel] stops
  /// the model request.
  ///
  /// Throws an [AiServiceException] when the request fails.
  Future<Map<String, String>> generate(
    String projectName,
    String description, {
    AiCancelToken? cancel,
  }) async {
    final reply = await _model.generate(
      _mainPrompt(projectName, description),
      AppDuration.aiGenerateTimeout,
      cancel: cancel,
    );
    return {
      'pubspec.yaml': _pubspec(
        projectName,
        description,
        await _dartConstraint(),
      ),
      'README.md': _readme(projectName, description),
      'lib/main.dart': _mainDart(reply) ?? _basicMain(projectName, description),
    };
  }

  /// Dart SDK constraint matching the installed Flutter, such as `^3.9.2`.
  Future<String> _dartConstraint() async {
    final dartVersion = (await _sdk.versions())?.dart;
    return dartVersion == null ? _fallbackDartConstraint : '^$dartVersion';
  }

  /// The model's `lib/main.dart` in [reply]: its first code block that
  /// looks like one, else the whole reply when it does; null when none
  /// does.
  static String? _mainDart(String reply) {
    bool isMain(String code) =>
        code.contains(_mainFunction) || code.contains(_materialImport);
    for (final match in _codeBlock.allMatches(reply)) {
      final code = match.group(1)?.trim();
      if (code != null && code.isNotEmpty && isMain(code)) return code;
    }
    final whole = reply.trim();
    return isMain(whole) ? whole : null;
  }

  /// The prompt asking the model for the `lib/main.dart` of the app
  /// [projectName] matching [description].
  static String _mainPrompt(String projectName, String description) =>
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
9. Name the app "$projectName" and include proper project structure, basic routing, and theme configuration.

Customer description:
"$description"
''';

  /// The `pubspec.yaml` of [projectName] described by [description] and
  /// requiring [sdkConstraint].
  static String _pubspec(
    String projectName,
    String description,
    String sdkConstraint,
  ) =>
      '''
name: $projectName
description: ${_yamlLine(description)}
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: $sdkConstraint
  flutter: '>=3.0.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

''';

  /// [text] as one double-quoted YAML scalar: JSON strings are valid YAML,
  /// and line breaks become spaces.
  static String _yamlLine(String text) =>
      jsonEncode(text.replaceAll(_lineBreaks, ' ').trim());

  /// [text] as a Dart string literal: JSON strings are valid Dart once
  /// `$` can't start an interpolation.
  static String _dartString(String text) =>
      jsonEncode(text).replaceAll(r'$', r'\$');

  /// The `README.md` of [projectName] described by [description].
  static String _readme(String projectName, String description) =>
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

  /// A basic app titled [projectName] showing [description], for when the
  /// model wrote no usable code.
  static String _basicMain(String projectName, String description) =>
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
              ${_dartString(description)},
            ),
          ],
        ),
      ),
    );
  }
}
''';
}
