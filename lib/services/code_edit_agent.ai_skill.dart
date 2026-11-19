part of 'code_edit_agent.dart';

/// One tool the model may call: its name, what it does, the JSON schema
/// of its arguments and the code that runs it.
class AiSkill {
  /// Marks a step of a tool the model isn't given.
  static const String unknownIcon = '🔧';

  /// Name the model calls the skill by.
  final String name;

  /// The emoji starting the skill's step lines in the chat, telling the
  /// action at a glance, such as 👓 for reading and ✏️ for writing.
  final String icon;

  /// What the skill does, for the model.
  final String description;

  /// Required argument names mapped to their descriptions; all are
  /// strings.
  final Map<String, String> parameters;

  /// Arguments the model may leave out, as [parameters] lists them.
  final Map<String, String> optionalParameters;

  /// Whether the skill changes the project, so calls before it may give
  /// other results after it.
  final bool changesProject;

  /// Whether the result depends on the arguments; false when they only
  /// describe the call, as `check_build`'s summary of the changes does.
  final bool usesArguments;

  /// Runs the skill with the model's arguments and returns its result for
  /// the model. Throws a [FormatException] or [FileSystemException] the
  /// agent reports back to the model.
  final Future<String> Function(Map<String, dynamic> arguments) run;

  /// Creates a skill.
  const AiSkill({
    required this.name,
    required this.icon,
    required this.description,
    required this.parameters,
    this.optionalParameters = const {},
    this.changesProject = false,
    this.usesArguments = true,
    required this.run,
  });

  /// What identifies a call of the skill with [arguments]: two calls with
  /// the same key give the same result while the project doesn't change.
  String callKey(Map<String, dynamic> arguments) =>
      usesArguments ? '$name ${jsonEncode(arguments)}' : name;

  /// The skill as an Ollama tool definition.
  Map<String, dynamic> toTool() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          for (final MapEntry(key: name, value: description) in {
            ...parameters,
            ...optionalParameters,
          }.entries)
            name: {'type': 'string', 'description': description},
        },
        'required': parameters.keys.toList(),
      },
    },
  };
}
