// ignore: fcheck_dead_code
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/text_truncation.dart';
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

  /// Path of Ollama's chat endpoint, which supports tool calling.
  static const String _chatPath = '/api/chat';

  /// Path of Ollama's endpoint describing one model.
  static const String _showPath = '/api/show';

  /// Path of Ollama's endpoint listing downloaded models.
  static const String _tagsPath = '/api/tags';

  /// Capability Ollama reports for models that can call tools.
  static const String _toolsCapability = 'tools';

  final FlutterSdk _sdk;
  final http.Client _client;

  String _model = OllamaInstaller.model;
  bool _isModelResolved = false;
  bool _supportsTools = true;

  /// Creates an AI service that reads SDK versions from [_sdk] and sends
  /// requests through [client] (a fresh one by default).
  AIService([this._sdk = const FlutterSdk(), http.Client? client])
    : _client = client ?? http.Client();

  /// Whether [model] stands in for [OllamaInstaller.model], which isn't
  /// downloaded or can't call tools.
  bool get isFallbackModel => !_isPreferred(_model);

  /// The model requests go to; see [resolveModel].
  String get model => _model;

  /// Whether [model] can call tools, which Fix Build needs to edit files.
  bool get supportsTools => _supportsTools;

  /// Picks the model requests go to among the downloaded ones and returns
  /// it, or null when none is downloaded: [OllamaInstaller.model] first,
  /// then any model that can call tools, then any model.
  ///
  /// Throws an [AiServiceException] when Ollama can't be reached.
  Future<String?> resolveModel() async {
    final tags = await _send(_tagsPath, AppDuration.aiSuggestionTimeout);
    final listed = tags?['models'];
    final names = [
      if (listed is List)
        for (final entry in listed)
          if (entry is Map && entry['name'] is String) entry['name'] as String,
    ];
    if (names.isEmpty) return null;
    final candidates = [
      ...names.where(_isPreferred),
      ...names.where((name) => !_isPreferred(name)),
    ];
    var chosen = candidates.first;
    var canCallTools = false;
    for (final name in candidates) {
      if (await _canCallTools(name)) {
        chosen = name;
        canCallTools = true;
        break;
      }
    }
    _model = chosen;
    _supportsTools = canCallTools;
    _isModelResolved = true;
    return chosen;
  }

  /// Whether Ollama says [name] can call tools; true when it doesn't say,
  /// as older Ollama versions report no capabilities.
  Future<bool> _canCallTools(String name) async {
    final details = await _send(_showPath, AppDuration.aiSuggestionTimeout, {
      'model': name,
    });
    final capabilities = details?['capabilities'];
    return capabilities is! List || capabilities.contains(_toolsCapability);
  }

  /// Whether [name] is [OllamaInstaller.model] under any tag.
  bool _isPreferred(String name) =>
      name == OllamaInstaller.model ||
      name.startsWith('${OllamaInstaller.model}:');

  /// Sends [body] (plus the model name) to Ollama's [path], resolving the
  /// model first when [resolveModel] hasn't, and returns the reply like
  /// [_send].
  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, Object> body,
    Duration timeout,
  ) async {
    if (!_isModelResolved) {
      try {
        await resolveModel();
      } on AiServiceException {
        // The request below reports the failure
      }
    }
    return _send(path, timeout, {'model': _model, 'stream': false, ...body});
  }

  /// Posts [body] to Ollama's [path], or gets it when [body] is null, and
  /// returns the decoded JSON reply, or null when it isn't a JSON object.
  ///
  /// Throws an [AiServiceException] when Ollama can't be reached within
  /// [timeout] or answers with an error status.
  Future<Map<String, dynamic>?> _send(
    String path,
    Duration timeout, [
    Map<String, Object>? body,
  ]) async {
    final uri = Uri.http(ollamaHost, path);
    final http.Response response;
    try {
      response =
          await (body == null
                  ? _client.get(uri)
                  : _client.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ))
              .timeout(timeout);
    } catch (e) {
      throw AiServiceException(
        '$e\n\nMake sure Ollama is installed and running on $ollamaHost',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AiServiceException(
        'Failed to get AI response (${response.statusCode}). Make sure Ollama is running with the $_model model.\n${response.body}',
      );
    }
    final Object? data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    return data is Map<String, dynamic> ? data : null;
  }

  /// Sends [prompt] to the model and returns its response text, which may
  /// be empty; [contextTokens] widens the model's context window for long
  /// prompts. Throws like [_post].
  Future<String> _generate(
    String prompt,
    Duration timeout, {
    int? contextTokens,
  }) async {
    final data = await _post(_generatePath, {
      'prompt': prompt,
      if (contextTokens != null) 'options': {'num_ctx': contextTokens},
    }, timeout);
    return data?['response']?.toString() ?? '';
  }

  /// Sends the conversation [messages] with the [tools] the model may call
  /// and returns the model's reply message, whose `tool_calls` list the
  /// calls it wants run. Throws like [_post].
  Future<Map<String, dynamic>> chat(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    final data = await _post(_chatPath, {
      'messages': messages,
      'tools': tools,
    }, AppDuration.aiToolStepTimeout);
    final message = data?['message'];
    return message is Map<String, dynamic> ? message : const {};
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

  /// Runs [action] on the user's [text]; [context] is the selected file's
  /// content for [AiAction.ask], the last build errors for
  /// [AiAction.fixBuild] and fcheck's findings with their code for the
  /// reviews, and is not sent for the other actions.
  ///
  /// Fix Build here only suggests changes; `CodeEditAgent` makes them.
  Future<String> respond(AiAction action, String text, String context) {
    return switch (action) {
      AiAction.ask => getCodeSuggestion(text, context),
      AiAction.explain => explainCode(text),
      AiAction.generate => generateCode(text),
      AiAction.refactor => refactorCode(text, 'Please refactor this code'),
      AiAction.fixBuild => fixBuild(text, context),
      AiAction.dryReview => reviewCode(
        'Below are the duplicate code pairs and repeated string literals '
        'fcheck found. Decide which are real duplication worth removing; '
        'for each, name the files involved and the shared helper, widget '
        'or constant to extract.',
        text,
        context,
      ),
      AiAction.solidReview => reviewCode(
        'Below are the largest classes, the most coupled files and the '
        'layer violations fcheck found, with the source of the largest '
        'classes. Check them against the SOLID principles: single '
        'responsibility, open/closed, Liskov substitution, interface '
        'segregation and dependency inversion. For each violation, name '
        'the principle, the file and class, and the change that fixes it.',
        text,
        context,
      ),
    };
  }

  /// Reviews the project [findings] (fcheck's results and the code they
  /// point to) as [instructions] say, with the user's [notes] on what to
  /// focus on, and returns the review in Markdown.
  Future<String> reviewCode(
    String instructions,
    String notes,
    String findings,
  ) {
    return _generate(
      '''
You are a senior Flutter/Dart reviewer.

$instructions

List the most important findings first, as Markdown. Only report problems you can point to in the code.

$notes

$findings''',
      AppDuration.aiReviewTimeout,
      contextTokens: AppMetric.aiReviewContextTokens,
    );
  }

  /// Explains the cause of failed build output and the code changes that
  /// fix it; [errors] is the build's error output and [notes] any errors
  /// or details the user added.
  Future<String> fixBuild(String notes, String errors) {
    return getCodeSuggestion('''
This Flutter/Dart build failed. Find the root cause of each error and show the code changes that fix it, naming the file each change belongs to.

$notes''', errors);
  }

  /// Writes a one-line commit message stating the intent of the changes
  /// in [diff], cut to [AppMetric.aiCommitDiffChars].
  ///
  /// Throws an [AiServiceException] when the request fails.
  Future<String> commitMessage(String diff) async {
    final changes = diff.truncated(AppMetric.aiCommitDiffChars);
    final response = await _generate('''
Write a short, one-line git commit message stating the intent of these changes.
Reply with the message only: no quotes, no prefix, no explanation.

$changes''', AppDuration.aiGenerateTimeout);
    final line = response
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return line.replaceAll(RegExp(r'''^[`"']+|[`"']+$'''), '');
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
