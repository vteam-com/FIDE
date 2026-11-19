/// A Flutter, Dart or CocoaPods command the AI agent runs in a project,
/// read from the command line the model writes: only the [allowed]
/// dependency, code generation and fix chores, with arguments that stay in
/// the project, run without a shell, so nothing in the line can start
/// another command, delete files or reach outside the project.
class ProjectCommand {
  const ProjectCommand._(this.words);

  /// The tool, then its arguments, as the model wrote them.
  final List<String> words;

  /// The `pub` subcommands managing a project's dependencies: not
  /// `publish`, `global` or `cache`, which reach beyond the project.
  static const List<String> _pubCommands = [
    'get',
    'upgrade',
    'downgrade',
    'add',
    'remove',
    'outdated',
    'deps',
  ];

  /// The commands the agent may run, by their first words, each mapped to
  /// the word that may follow them; any arguments come after.
  static const Map<String, List<String>> _allowed = {
    'flutter pub': _pubCommands,
    'dart pub': _pubCommands,
    'flutter': ['gen-l10n'],
    'dart': ['fix', 'format'],
    'dart run build_runner': ['build'],
    'pod': ['install', 'update'],
    'pod repo': ['update'],
  };

  /// The commands the agent may run, for the model, such as
  /// `flutter pub get|upgrade, pod install|update`.
  static final String allowed = [
    for (final MapEntry(key: start, value: next) in _allowed.entries)
      '$start ${next.join('|')}',
  ].join(', ');

  /// The characters an argument may hold: those of package names, version
  /// constraints such as `foo:^1.2.0`, flags and project paths. None a
  /// shell gives meaning to, such as `&`, `|`, `;`, `>`, `$` or `%`.
  static final RegExp _argument = RegExp(r'^[\w@.,:=/+^-]+$');

  /// A Windows drive at the start of an argument or its value, as in
  /// `C:/` or `--directory=C:/`.
  static final RegExp _drive = RegExp(r'(^|=)[A-Za-z]:[/\\]');

  /// The spaces between the words of a command line.
  static final RegExp _spaces = RegExp(r'\s+');

  /// Quotes or backticks the model may wrap the whole line in.
  static final RegExp _lineQuotes = RegExp('^[\'"`]+|[\'"`]+\$');

  /// Quotes the model may wrap a word in, such as a version constraint.
  static final RegExp _wordQuotes = RegExp('^[\'"]+|[\'"]+\$');

  /// The tool the command runs: `flutter`, `dart` or `pod`.
  String get executable => words.first;

  /// The command's arguments, after its [executable].
  List<String> get arguments => words.sublist(1);

  /// The command as one line, as the model wrote it.
  String get line => words.join(' ');

  /// The command [line] the model wrote, such as
  /// `flutter pub upgrade google_sign_in_ios`.
  ///
  /// Throws a [FormatException] telling the model what it may run instead
  /// when the line is not one of the [allowed] commands, chains commands,
  /// or has an argument outside the project.
  static ProjectCommand parse(String line) {
    final text = line.trim().replaceAll(_lineQuotes, '');
    if (text.contains('\n')) {
      throw const FormatException('Run one command per call.');
    }
    final words = [
      for (final word in text.split(_spaces))
        if (word.replaceAll(_wordQuotes, '') case final bare
            when bare.isNotEmpty)
          bare,
    ];
    if (words.isEmpty) throw const FormatException('The command is empty.');
    for (final word in words) {
      if (!_argument.hasMatch(word)) {
        throw FormatException(
          'Run one command per call, without cd, &&, |, ;, > or quotes '
          'around spaces; use folder to run it in a subfolder. "$word" is '
          'not allowed.',
        );
      }
      if (_leavesProject(word)) {
        throw FormatException('$word is outside the project.');
      }
    }
    if (!_isAllowed(words)) {
      throw FormatException(
        '${words.join(' ')} is not allowed. Commands you can run: $allowed.',
      );
    }
    return ProjectCommand._(words);
  }

  /// Whether [words] start with one of the [_allowed] commands.
  static bool _isAllowed(List<String> words) => _allowed.entries.any((entry) {
    final start = entry.key.split(' ');
    return words.length > start.length &&
        words.take(start.length).join(' ') == entry.key &&
        entry.value.contains(words[start.length]);
  });

  /// Whether the argument [word] points outside the project: an absolute
  /// path or a parent folder, alone or as a flag's value.
  static bool _leavesProject(String word) =>
      word.startsWith('/') ||
      word.contains('=/') ||
      word.split(RegExp('[=/]')).contains('..') ||
      _drive.hasMatch(word);
}
