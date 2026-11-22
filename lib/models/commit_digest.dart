import 'dart:math';

import 'package:fide/models/text_truncation.dart';

/// What the model reads of the changes a commit records, worked out by
/// code so a change of any size keeps its meaning within [maxChars]: the
/// files changed, the documentation added, the declarations added with
/// the first sentence of their documentation, the tests added by name,
/// then as much of the diff of each file as the rest of the budget holds,
/// shared between them.
///
/// The head of a large diff is the first few files only, often the
/// least telling; this digest reads the whole of it.
class CommitDigest {
  /// Digests [changes], `git diff --stat` followed by the unified diff,
  /// for a model reading at most [maxChars].
  CommitDigest(String changes, {required this.maxChars}) {
    final start = changes.startsWith(_fileHeader)
        ? 0
        : changes.indexOf('\n$_fileHeader');
    // Only its end trimmed: git indents each of its lines
    _stat = (start == -1 ? changes : changes.substring(0, start)).trimRight();
    if (start == -1) return;
    _FileDiff? file;
    for (final line in changes.substring(start).trim().split('\n')) {
      if (line.startsWith(_fileHeader)) {
        file = _FileDiff(line);
        _files.add(file);
      } else {
        file?.read(line);
      }
    }
  }

  /// Share of [maxChars] the list of files changed takes at most.
  static const double _statShare = 0.2;

  /// Share of [maxChars] the documentation added takes at most.
  static const double _docsShare = 0.2;

  /// Share of [maxChars] the declarations added take at most.
  static const double _declarationsShare = 0.3;

  /// Share of [maxChars] the names of the tests added take at most.
  static const double _testsShare = 0.1;

  /// Fewest characters of a file's diff the changes section shows.
  static const int _minFileShare = 600;

  /// The starts of the lines the changes section leaves out: comments
  /// and directives.
  static const List<String> _notCode = ['//', 'import ', 'export ', 'part '];

  /// The keywords a declaration line may start with, which [_member]
  /// would take for a name.
  static const Set<String> _keywords = {
    'await',
    'const',
    'external',
    'factory',
    'final',
    'if',
    'late',
    'return',
    'static',
    'switch',
    'var',
  };

  /// The bar graph ending a line of `git diff --stat`, the count kept in
  /// group 1.
  static final RegExp _statBars = RegExp(
    r'(\|\s+\d+)\s+[+-]+$',
    multiLine: true,
  );

  /// Most characters of a declaration's first sentence.
  static const int _maxSentenceChars = 160;

  /// The line starting each file's diff.
  static const String _fileHeader = 'diff --git ';

  /// The extensions of documentation files.
  static const Set<String> _docExtensions = {'.md', '.markdown'};

  /// The folders holding tests.
  static const List<String> _testFolders = ['test/', 'integration_test/'];

  /// A type declaration: `class FileMover`, `enum AnalyzerReview`,
  /// `typedef DartFileLister`; the name in group 1.
  static final RegExp _type = RegExp(
    r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
    r'(?:class|enum|mixin|extension\s+type|extension|typedef)\s+'
    r'([A-Z]\w*)',
  );

  /// A provider: `final fileMoverProvider = ...`; the name in group 1.
  static final RegExp _provider = RegExp(r'^final\s+(\w+Provider)\b');

  /// A public function, method, getter or enum value: `plan(`,
  /// `String get label =>`, `layout('File Layout')`; the name in group 1.
  static final RegExp _member = RegExp(
    r'^(?:[\w<>?,\[\]. ]+\s)?(?:get\s+)?([a-z]\w*)\s*(?:<[^()]*>)?'
    r'\s*(?:\(|=>|\{)',
  );

  /// A test or group: `test(`, `testWidgets(`, `group(`; what follows
  /// the parenthesis in group 1.
  static final RegExp _testCall = RegExp(
    r'\b(?:test|testWidgets|group)\(\s*(.*)$',
  );

  /// A string literal, single or double quoted, its text in the group
  /// [_literalText].
  static final RegExp _stringLiteral = RegExp(
    r"""^\s*(?<quote>['"])(?<text>(?:(?!\k<quote>)[^\\]|\\.)*)\k<quote>""",
  );

  /// The group of [_stringLiteral] holding the literal's text.
  static const String _literalText = 'text';

  /// A Dart escape in a test name: `\$`, `\'`.
  static final RegExp _escape = RegExp(r'\\(.)');

  /// The end of a sentence.
  static final RegExp _sentenceEnd = RegExp(r'\.(?:\s|$)');

  /// A dartdoc reference: `[FileMove]`; the name in group 1.
  static final RegExp _reference = RegExp(r'\[([\w.]+)\]');

  /// The most the model reads.
  final int maxChars;

  final List<_FileDiff> _files = [];

  late final String _stat;

  /// The digest the model reads.
  String get text {
    final sections = [
      _section(
        'Files changed',
        _stat.replaceAllMapped(_statBars, (m) => m.group(1)!),
        _statShare,
      ),
      _section('Documentation added', _docs(), _docsShare),
      _section(
        'Declarations added, with the first sentence of their documentation',
        _declarations(),
        _declarationsShare,
      ),
      _section('Tests added', _tests(), _testsShare),
    ].where((section) => section.isNotEmpty).toList();
    final used = sections.fold(0, (sum, section) => sum + section.length);
    final changes = _changes(maxChars - used);
    return [
      ...sections,
      if (changes.isNotEmpty) 'Changes:\n$changes',
    ].join('\n\n').truncated(maxChars);
  }

  /// The source files, not documentation nor tests, most changed first.
  List<_FileDiff> get _sources => [
    for (final file in _files)
      if (!_isDoc(file) && !_isTest(file)) file,
  ]..sort((a, b) => b.added.length.compareTo(a.added.length));

  /// The code lines the source files change, most changed file first,
  /// each file taking an equal share of [budget], at least
  /// [_minFileShare], as long as [budget] lasts; directives, comments and
  /// blank lines left out, as the other sections tell them.
  String _changes(int budget) {
    final files = [
      for (final file in _sources)
        if (!file.isDeleted)
          if ([
                for (final line in file.changed)
                  if (_isCode(line.substring(1).trim())) line,
              ]
              case final lines when lines.isNotEmpty)
            '${file.path}\n${lines.join('\n')}',
    ];
    if (files.isEmpty || budget < _minFileShare) return '';
    final share = max(budget ~/ files.length, _minFileShare);
    return files
        .take(budget ~/ share)
        .map((file) => file.truncated(share))
        .join('\n');
  }

  /// Each public declaration the source files add right after its
  /// documentation, with the first sentence of it, under its file.
  String _declarations() => [
    for (final file in _sources)
      if (_declaredIn(file) case final declared when declared.isNotEmpty)
        '${file.path}\n${declared.join('\n')}',
  ].join('\n');

  /// The documented declarations [file] adds, one line each.
  List<String> _declaredIn(_FileDiff file) {
    final declared = <String>[];
    final doc = <String>[];
    for (final (:line, :isAdded) in file.lines) {
      final code = line.trim();
      if (!isAdded) {
        doc.clear();
      } else if (code.startsWith('///')) {
        doc.add(code.substring('///'.length).trim());
      } else if (!code.startsWith('@')) {
        final name =
            (_type.firstMatch(code) ??
                    _provider.firstMatch(code) ??
                    _member.firstMatch(code))
                ?.group(1);
        if (name != null && !_keywords.contains(name) && doc.isNotEmpty) {
          declared.add('- $name: ${_firstSentence(doc.join(' '))}');
        }
        doc.clear();
      }
    }
    return declared;
  }

  /// The lines the documentation files add.
  ///
  /// Only the lines added anew, when there are: an edited line mostly
  /// repeats what was there.
  String _docs() {
    final docs = _files.where(_isDoc);
    String linesOf(List<String> Function(_FileDiff file) pick) => [
      for (final file in docs)
        for (final line in pick(file))
          if (line.trim().isNotEmpty) line.trim(),
    ].join('\n');
    final fresh = linesOf((file) => file.addedAnew);
    return fresh.isNotEmpty ? fresh : linesOf((file) => file.added);
  }

  /// The names of the tests and groups the test files add.
  String _tests() {
    final names = <String>[];
    for (final file in _files.where(_isTest)) {
      final added = file.added;
      for (var i = 0; i < added.length; i++) {
        final call = _testCall.firstMatch(added[i]);
        if (call == null) continue;
        var (name, continues) = _leadingStrings(call.group(1)!);
        while (continues && i + 1 < added.length) {
          final (more, goesOn) = _leadingStrings(added[i + 1]);
          if (more.isEmpty) break;
          name += more;
          continues = goesOn;
          i++;
        }
        if (name.isNotEmpty) names.add('- $name');
      }
    }
    return names.join('\n');
  }

  /// [doc]'s first sentence, its references as plain names, cut to
  /// [_maxSentenceChars].
  static String _firstSentence(String doc) {
    final plain = doc.replaceAllMapped(_reference, (m) => m.group(1)!);
    final end = _sentenceEnd.firstMatch(plain);
    return (end == null ? plain : plain.substring(0, end.start + 1)).truncated(
      _maxSentenceChars,
    );
  }

  /// Whether [code], a changed line without its sign, is code the
  /// changes section shows: not blank, a comment nor a directive.
  static bool _isCode(String code) =>
      code.isNotEmpty && !_notCode.any(code.startsWith);

  /// Whether [file] is documentation.
  static bool _isDoc(_FileDiff file) =>
      _docExtensions.any(file.path.toLowerCase().endsWith);

  /// Whether [file] is a test.
  static bool _isTest(_FileDiff file) => _testFolders.any(file.path.startsWith);

  /// The text of the string literals [code] starts with, joined, and
  /// whether they end the line, so the text may go on on the next one.
  static (String, bool) _leadingStrings(String code) {
    final text = StringBuffer();
    var rest = code;
    for (
      var literal = _stringLiteral.firstMatch(rest);
      literal != null;
      literal = _stringLiteral.firstMatch(rest)
    ) {
      text.write(
        literal
            .namedGroup(_literalText)!
            .replaceAllMapped(_escape, (m) => m.group(1)!),
      );
      rest = rest.substring(literal.end);
    }
    return (text.toString(), rest.trim().isEmpty);
  }

  /// [body] under [title], cut to [share] of [maxChars]; empty when
  /// [body] is.
  String _section(String title, String body, double share) => body.isEmpty
      ? ''
      : '$title:\n$body'.truncated((maxChars * share).floor());
}

/// One file's part of a unified diff: its path and lines.
class _FileDiff {
  /// Starts the file whose diff [header] (`diff --git a/x b/y`) starts.
  _FileDiff(String header)
    : path = header.substring(header.lastIndexOf(_newSide) + _newSide.length);

  /// What starts the path of the file's new side in a diff header.
  static const String _newSide = ' b/';

  /// What starts a line of a deleted file's diff header.
  static const String _deletedMode = 'deleted file mode';

  /// What starts the lines naming the old and new sides of a file.
  static const List<String> _sideHeaders = ['--- ', '+++ '];

  /// Whether the change deletes the file.
  bool isDeleted = false;

  /// The file's lines in the diff, added or not, after its header.
  final List<({String line, bool isAdded})> lines = [];

  /// The project-relative path of the file.
  final String path;

  /// The lines the change adds.
  List<String> get added => [
    for (final (:line, :isAdded) in lines)
      if (isAdded) line,
  ];

  /// The lines the change adds that replace none it removes.
  final List<String> addedAnew = [];

  /// The lines the change adds or removes, each with its `+` or `-`.
  final List<String> changed = [];

  /// Whether the lines read last were removed, so the lines added next
  /// replace them.
  bool _replacing = false;

  /// Reads [line], the next line of the file's diff.
  void read(String line) {
    if (line.startsWith(_deletedMode)) isDeleted = true;
    if (_sideHeaders.any(line.startsWith)) return;
    final isAdded = line.startsWith('+');
    final isRemoved = line.startsWith('-');
    if (isAdded || isRemoved) changed.add(line);
    final text = isAdded ? line.substring(1) : line;
    if (isAdded && !_replacing) addedAnew.add(text);
    if (!isAdded) _replacing = isRemoved;
    lines.add((line: text, isAdded: isAdded));
  }
}
