import 'dart:convert';

import 'package:fide/models/model_message.dart';

/// Tool calls a model wrote into its reply's text instead of returning
/// them as `tool_calls`, which Ollama misses when the model drifts from
/// its template, such as qwen3-coder leaving out the opening
/// `<tool_call>` tag. Reads qwen3-coder's XML calls
/// (`<function=read_file><parameter=path>lib/a.dart</parameter></function>`)
/// and JSON ones (`<tool_call>{"name": …, "arguments": {…}}</tool_call>`).
class TextToolCalls {
  /// Not instantiated: a namespace for [parse] and [textBefore].
  const TextToolCalls._();

  /// One XML call: the tool's name, then its parameters.
  static final RegExp _xmlCall = RegExp(
    r'<function=(?<name>[\w.-]+)>(?<body>.*?)</function>',
    dotAll: true,
  );

  /// One parameter of an XML call: its name, then its value.
  static final RegExp _xmlParameter = RegExp(
    r'<parameter=(?<name>[\w.-]+)>(?<value>.*?)</parameter>',
    dotAll: true,
  );

  /// One JSON call between `<tool_call>` tags.
  static final RegExp _jsonCall = RegExp(
    r'<tool_call>\s*(?<json>\{.*?\})\s*</tool_call>',
    dotAll: true,
  );

  /// Where a written call starts.
  static final RegExp _callStart = RegExp(r'<tool_call>|<function=');

  /// The calls written in [content], as Ollama `tool_calls` entries; none
  /// when it holds no call.
  static List<Map<String, dynamic>> parse(String content) => [
    for (final call in _xmlCall.allMatches(content))
      ModelMessage.toolCall(call.namedGroup('name')!, {
        for (final parameter in _xmlParameter.allMatches(
          call.namedGroup('body')!,
        ))
          parameter.namedGroup('name')!: _xmlValue(
            parameter.namedGroup('value')!,
          ),
      }),
    for (final call in _jsonCall.allMatches(content))
      ?_fromJson(call.namedGroup('json')!),
  ];

  /// What [content] says before its first written call, trimmed.
  static String textBefore(String content) {
    final start = content.indexOf(_callStart);
    return (start < 0 ? content : content.substring(0, start)).trim();
  }

  /// The call [json] describes, or null when it is no
  /// `{"name": …, "arguments": {…}}` object.
  static Map<String, dynamic>? _fromJson(String json) {
    try {
      final call = jsonDecode(json);
      if (call case {
        ModelMessage.nameKey: final String name,
        ModelMessage.argumentsKey: final Map<String, dynamic> arguments,
      }) {
        return ModelMessage.toolCall(name, arguments);
      }
    } on FormatException {
      // Not a call: left as text
    }
    return null;
  }

  /// [value] without the line breaks the template puts around it, keeping
  /// the rest exactly, as replacing text needs its whitespace.
  static String _xmlValue(String value) {
    final start = value.startsWith('\n') ? 1 : 0;
    final end = value.length > start && value.endsWith('\n')
        ? value.length - 1
        : value.length;
    return value.substring(start, end);
  }
}
