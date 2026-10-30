part of 'code_edit_agent.dart';

/// One tool the model may call: its name, what it does, the JSON schema
/// of its arguments and the code that runs it.
class AiSkill {
  /// Name the model calls the skill by.
  final String name;

  /// What the skill does, for the model.
  final String description;

  /// Argument names mapped to their descriptions; all are strings.
  final Map<String, String> parameters;

  /// Runs the skill with the model's arguments and returns its result for
  /// the model. Throws a [FormatException] or [FileSystemException] the
  /// agent reports back to the model.
  final Future<String> Function(Map<String, dynamic> arguments) run;

  /// Creates a skill.
  const AiSkill({
    required this.name,
    required this.description,
    required this.parameters,
    required this.run,
  });

  /// The skill as an Ollama tool definition.
  Map<String, dynamic> toTool() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          for (final MapEntry(key: name, value: description)
              in parameters.entries)
            name: {'type': 'string', 'description': description},
        },
        'required': parameters.keys.toList(),
      },
    },
  };
}
