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
