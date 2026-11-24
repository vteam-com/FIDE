/// What a prompt to the AI panel asks for, read from its words by code,
/// not left to the model: a local model given tools to edit files with
/// edits them even for "2+2=".
class PromptIntent {
  /// Not instantiated: a namespace for [asksForChange] and
  /// [refersToOpenFile].
  const PromptIntent._();

  /// Verbs a request to change the code, or to run a command on it such
  /// as `flutter pub upgrade`, starts with.
  static const Set<String> _changeVerbs = {
    'add',
    'adjust',
    'align',
    'append',
    'apply',
    'center',
    'change',
    'clean',
    'convert',
    'correct',
    'create',
    'delete',
    'disable',
    'document',
    'downgrade',
    'drop',
    'edit',
    'enable',
    'extract',
    'fix',
    'format',
    'generate',
    'implement',
    'improve',
    'inline',
    'insert',
    'install',
    'introduce',
    'localize',
    'make',
    'merge',
    'migrate',
    'modify',
    'move',
    'optimize',
    'refactor',
    'regenerate',
    'remove',
    'rename',
    'reorder',
    'replace',
    'resize',
    'rewrite',
    'run',
    'set',
    'simplify',
    'sort',
    'split',
    'swap',
    'translate',
    'update',
    'upgrade',
    'use',
    'wrap',
    'write',
  };

  /// A polite or conversational opening before the request's verb.
  static final RegExp _opening = RegExp(
    r"^(please|pls|kindly|now|then|also|ok|okay|go ahead and|let's|lets|"
    r"can you|could you|would you|will you|"
    r"i want you to|i'd like you to|i need you to)\b[\s,]*",
  );

  /// The first word of a text.
  static final RegExp _firstWord = RegExp('^[a-z]+');

  /// Words naming the whole project, which "this" or "current" then
  /// points at instead of the open file.
  static const String _wholeProject =
      'project|app|application|codebase|code base|repo|repository|'
      'workspace|package';

  /// Words pointing at the file open in the editor: "this", "current" or
  /// "selected", unless they point at the whole project, as "this
  /// project" does, which got MiMo reading only the open file when asked
  /// for a typo in the project.
  static final RegExp _openFile = RegExp(
    r'\b(?:(?:this|current|selected)\b(?!\s+(?:whole\s+|entire\s+)?(?:'
    '$_wholeProject'
    r')\b)|here|open file|the file|my file)\b',
    caseSensitive: false,
  );

  /// Whether [prompt] asks to change the code: past a polite opening such
  /// as "please" or "can you", it starts with a verb such as fix, add or
  /// rename. Anything else, such as a question or "2+2=", asks for an
  /// answer.
  static bool asksForChange(String prompt) {
    var text = prompt.trim().toLowerCase();
    for (
      var rest = text.replaceFirst(_opening, '');
      rest != text;
      rest = text.replaceFirst(_opening, '')
    ) {
      text = rest;
    }
    return _changeVerbs.contains(_firstWord.firstMatch(text)?.group(0));
  }

  /// Whether [prompt] points at the file open in the editor, as "this
  /// file" or "here" do.
  static bool refersToOpenFile(String prompt) => _openFile.hasMatch(prompt);
}
