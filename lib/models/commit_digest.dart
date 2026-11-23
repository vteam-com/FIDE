import 'dart:math';

import 'package:fide/models/text_truncation.dart';

/// What the model reads of the changes a commit records, worked out by
/// code so a change of any size keeps its meaning within [maxChars]: the
/// files changed, the documentation added, the declarations added and
/// removed with the first sentence of their documentation, the
/// declarations renamed, the code moved unchanged, the tests added and
/// removed by name, then as much of the rest of the diff of each file as
/// the rest of the budget holds, shared between them.
///
/// The head of a large diff is the first few files only, often the
/// least telling; this digest reads the whole of it. Code moved is told
/// as moved, never as code removed and added: read as added, a class
/// moved into the file of its widget reads as a new feature.
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
    _matchMoves();
    _matchRenames();
  }

  /// Share of [maxChars] the list of files changed takes at most.
  static const double _statShare = 0.2;

  /// Share of [maxChars] the documentation added takes at most.
  static const double _docsShare = 0.2;

  /// Share of [maxChars] the declarations added take at most.
  static const double _declarationsShare = 0.25;

  /// Share of [maxChars] the names of the tests added take at most.
  static const double _testsShare = 0.1;

  /// Share of [maxChars] each of the declarations removed, renamed, the
  /// code moved and the tests removed takes at most.
  static const double _minorShare = 0.05;

  /// Fewest characters of a file's diff the changes section shows.
  static const int _minFileShare = 600;

  /// Fewest lines with a letter a move between two places carries for the
  /// digest to tell it: fewer may be lines alike by chance, as `@override`.
  static const int _minMovedLines = 3;

  /// The starts of the lines the changes section leaves out: comments
  /// and directives.
  static const List<String> _notCode = ['//', 'import ', 'export ', 'part '];

  /// The keywords a declaration line may start with, which [_member]
  /// would take for a name, and [_typedMember] for a type.
  static const Set<String> _keywords = {
    'await',
    'case',
    'const',
    'else',
    'external',
    'factory',
    'final',
    'if',
    'in',
    'is',
    'late',
    'new',
    'return',
    'static',
    'switch',
    'throw',
    'var',
    'yield',
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

  /// What starts a private name.
  static const String _private = '_';

  /// Where a declaration in no type is.
  static const String _topLevel = 'the top level';

  /// A type declaration: `class FileMover`, `enum AnalyzerReview`,
  /// `typedef DartFileLister`, `class _FooState`; the name in group 1.
  static final RegExp _type = RegExp(
    r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
    r'(?:class|enum|mixin|extension\s+type|extension|typedef)\s+'
    r'(_?[A-Z]\w*)',
  );

  /// A provider: `final fileMoverProvider = ...`; the name in group 1.
  static final RegExp _provider = RegExp(r'^final\s+(\w+Provider)\b');

  /// A function, method, getter or enum value: `plan(`,
  /// `String get label =>`, `layout('File Layout')`, `_load(`; the name
  /// in group 1.
  static final RegExp _member = RegExp(
    r'^(?:[\w<>?,\[\]. ]+\s)?(?:get\s+)?(_?[a-z]\w*)\s*(?:<[^()]*>)?'
    r'\s*(?:\(|=>|\{)',
  );

  /// A function, method or getter after its type, which a call is not:
  /// `String formatBytes(`, `int get count =>`; the type in the group
  /// [_memberType], the name in the group [_memberName].
  static final RegExp _typedMember = RegExp(
    r'^(?:static\s+)?(?<type>[\w<>?,\[\]]+)\s+(?:get\s+)?'
    r'(?<name>_?[a-z]\w*)\s*(?:<[^()]*>)?\s*(?:\(|=>)',
  );

  /// The group of [_typedMember] holding the member's type.
  static const String _memberType = 'type';

  /// The group of [_typedMember] holding the member's name.
  static const String _memberName = 'name';

  /// The ends of a declaration's line, its body or parameters following.
  static const List<String> _declarationEnds = ['{', '('];

  /// What a function written as an expression has on its line.
  static const String _arrow = '=>';

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

  /// A letter, which a line carrying meaning has, unlike `}` or `);`.
  static final RegExp _letter = RegExp('[A-Za-z]');

  /// The most the model reads.
  final int maxChars;

  final List<_FileDiff> _files = [];

  late final String _stat;

  /// The lines moved unchanged, removed and added, by the files they moved
  /// from and to, the same file for code moved within it.
  final Map<({_FileDiff from, _FileDiff to}), List<_DiffLine>> _moves = {};

  /// The declarations renamed, by their old and new names.
  final Set<({String from, String to})> _renames = {};

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
        _declarations(added: true),
        _declarationsShare,
      ),
      _section(
        'Declarations removed',
        _declarations(added: false),
        _minorShare,
      ),
      _section('Renamed', _renamed(), _minorShare),
      _section('Moved without change', _moved(), _minorShare),
      _section('Tests added', _tests(added: true), _testsShare),
      _section('Tests removed', _tests(added: false), _minorShare),
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
  /// [_minFileShare], as long as [budget] lasts; directives, comments,
  /// blank lines and the lines moved or renamed left out, as the other
  /// sections tell them.
  String _changes(int budget) {
    final shown = [
      for (final file in _sources)
        if (!file.isDeleted)
          if ([
                for (final line in file.changed)
                  if (_isCode(line.substring(1).trim())) line,
              ]
              case final lines when lines.isNotEmpty)
            '${file.path}\n${lines.join('\n')}',
    ];
    if (shown.isEmpty || budget < _minFileShare) return '';
    final share = max(budget ~/ shown.length, _minFileShare);
    return shown
        .take(budget ~/ share)
        .map((file) => file.truncated(share))
        .join('\n');
  }

  /// Whether a reported move joins [from] and [to], or they are one file.
  bool _connected(_FileDiff from, _FileDiff to) =>
      from == to ||
      _moves.keys.any((move) => move.from == from && move.to == to);

  /// Each documented public declaration the source files add, or remove
  /// when not [added], with the first sentence of its documentation,
  /// under its file; those moved or renamed left out, and a removed one
  /// still declared elsewhere.
  String _declarations({required bool added}) {
    final stillDeclared = added
        ? const <String>{}
        : {
            for (final file in _files)
              for (final line in file.lines)
                if (line.isAdded) ?_publicName(line.code),
          };
    return [
      for (final file in _sources)
        if ([
              for (final (:line, :name, :doc) in _documented(
                file,
                added: added,
              ))
                if (!line.isTold && !stillDeclared.contains(name))
                  '- $name: $doc',
            ]
            case final declared when declared.isNotEmpty)
          '${file.path}\n${declared.join('\n')}',
    ].join('\n');
  }

  /// The lines the documentation files add, but those moved.
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

  /// Marks the lines removed in one place and added unchanged, but for
  /// their indentation, in another as moved, so no section tells them as
  /// removed and added: those added back in their own run of changes are
  /// only indented anew, and a move between two places carrying fewer
  /// than [_minMovedLines] lines with a letter is left as changes, its
  /// lines alike by chance.
  void _matchMoves() {
    final removed = <String, List<({_FileDiff file, _DiffLine line})>>{};
    for (final file in _files) {
      for (final line in file.lines) {
        if (line.isRemoved && line.code.isNotEmpty) {
          (removed[line.code] ??= []).add((file: file, line: line));
        }
      }
    }
    for (final file in _files) {
      // Where the last line came from, so a block moves together
      _FileDiff? from;
      for (final line in file.lines) {
        final twins = line.isAdded ? removed[line.code] : null;
        if (twins == null || twins.isEmpty) continue;
        final twin = twins.removeAt(
          max(0, twins.indexWhere((twin) => twin.file == from)),
        );
        from = twin.file;
        twin.line.isTold = line.isTold = true;
        if (twin.file == file && twin.line.block == line.block) continue;
        line
          ..movedFrom = twin.file
          ..twin = twin.line;
        (_moves[(from: twin.file, to: file)] ??= [])
          ..add(twin.line)
          ..add(line);
      }
    }
    _moves.removeWhere((_, lines) {
      final isChance =
          lines.where((line) => line.isAdded && _hasLetter(line)).length <
          _minMovedLines;
      if (isChance) {
        for (final line in lines) {
          line
            ..isTold = false
            ..movedFrom = null
            ..twin = null;
        }
      }
      return isChance;
    });
  }

  /// Marks a declaration removed and one added in its place, under
  /// another name but for which their lines are alike, as renamed: in one
  /// file, or two a move joins.
  void _matchRenames() {
    final removed =
        <String, List<({_FileDiff file, _DiffLine line, String name})>>{};
    for (final file in _files) {
      for (final line in file.lines) {
        if (line.isRemoved && !line.isTold) {
          if (_renamable(line.code) case final name?) {
            (removed[_unnamed(line.code, name)] ??= []).add((
              file: file,
              line: line,
              name: name,
            ));
          }
        }
      }
    }
    for (final file in _files) {
      for (final line in file.lines) {
        if (!line.isAdded || line.isTold) continue;
        final name = _renamable(line.code);
        final twins = name == null ? null : removed[_unnamed(line.code, name)];
        final at = twins?.indexWhere((twin) => _connected(twin.file, file));
        if (twins == null || at == null || at == -1) continue;
        final twin = twins.removeAt(at);
        twin.line.isTold = line.isTold = true;
        _renames.add((from: twin.name, to: name!));
      }
    }
  }

  /// The code moved unchanged, by the places it moved between, with the
  /// documented public declarations it carries and the types they leave
  /// and join.
  String _moved() => [
    for (final MapEntry(key: (:from, :to), value: lines) in _moves.entries)
      [
        '- ${from == to ? '${to.path}, within the file' : '${from.label} → ${to.label}'}: '
            '${lines.where((line) => line.isAdded && _hasLetter(line)).length} '
            'lines',
        for (final MapEntry(key: scopes, value: names) in _carried(
          from,
          to,
        ).entries)
          '${names.join(', ')}$scopes',
      ].join(', '),
  ].join('\n');

  /// The documented public declarations moved from [from] to [to], by the
  /// types they move from and to, as ` from Foo to the top level`; by an
  /// empty text when they stay in the same type.
  Map<String, List<String>> _carried(_FileDiff from, _FileDiff to) {
    final carried = <String, List<String>>{};
    for (final (:line, :name, doc: _) in _documented(to, added: true)) {
      if (line.movedFrom != from) continue;
      final (old, now) = (line.twin?.scope, line.scope);
      final scopes = old == now
          ? ''
          : ' from ${old ?? _topLevel} to ${now ?? _topLevel}';
      (carried[scopes] ??= []).add(name);
    }
    return carried;
  }

  /// The declarations renamed, old name first, saying when the new name
  /// makes one private or public.
  String _renamed() => [
    for (final (:from, :to) in _renames)
      '- $from → $to'
          '${to == '$_private$from'
              ? ' (made private)'
              : from == '$_private$to'
              ? ' (made public)'
              : ''}',
  ].join('\n');

  /// [body] under [title], cut to [share] of [maxChars]; empty when
  /// [body] is.
  String _section(String title, String body, double share) => body.isEmpty
      ? ''
      : '$title:\n$body'.truncated((maxChars * share).floor());

  /// The names of the tests and groups the test files add, or remove when
  /// not [added], but those moved and those both added and removed, as
  /// a test whose first line changed.
  String _tests({required bool added}) {
    final other = _testNames(added: !added).toSet();
    return [
      for (final name in _testNames(added: added))
        if (!other.contains(name)) '- $name',
    ].join('\n');
  }

  /// The names of the tests and groups the test files add, or remove when
  /// not [added], but those moved.
  List<String> _testNames({required bool added}) {
    final names = <String>[];
    for (final file in _files.where(_isTest)) {
      final lines = [
        for (final line in file.lines)
          if ((added ? line.isAdded : line.isRemoved) && !line.isTold)
            line.text,
      ];
      for (var i = 0; i < lines.length; i++) {
        final call = _testCall.firstMatch(lines[i]);
        if (call == null) continue;
        var (name, continues) = _leadingStrings(call.group(1)!);
        while (continues && i + 1 < lines.length) {
          final (more, goesOn) = _leadingStrings(lines[i + 1]);
          if (more.isEmpty) break;
          name += more;
          continues = goesOn;
          i++;
        }
        if (name.isNotEmpty) names.add(name);
      }
    }
    return names;
  }

  /// The public declarations on [file]'s lines added, or removed when not
  /// [added], right after their documentation, with the first sentence
  /// of it.
  static List<({_DiffLine line, String name, String doc})> _documented(
    _FileDiff file, {
    required bool added,
  }) {
    final declared = <({_DiffLine line, String name, String doc})>[];
    final doc = <String>[];
    for (final line in file.lines) {
      final code = line.code;
      if (added ? !line.isAdded : !line.isRemoved) {
        doc.clear();
      } else if (code.startsWith('///')) {
        doc.add(code.substring('///'.length).trim());
      } else if (!code.startsWith('@')) {
        if (_publicName(code) case final name? when doc.isNotEmpty) {
          declared.add((
            line: line,
            name: name,
            doc: _firstSentence(doc.join(' ')),
          ));
        }
        doc.clear();
      }
    }
    return declared;
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

  /// Whether [line] carries meaning: it has a letter.
  static bool _hasLetter(_DiffLine line) => _letter.hasMatch(line.code);

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

  /// The public name [code] declares: a type, a provider or a member;
  /// null for none.
  static String? _publicName(String code) {
    final name =
        (_type.firstMatch(code) ??
                _provider.firstMatch(code) ??
                _member.firstMatch(code))
            ?.group(1);
    return name == null || name.startsWith(_private) || _keywords.contains(name)
        ? null
        : name;
  }

  /// The name, public or private, [code] declares when it is a type, a
  /// provider, or a function or getter with its type, which a rename may
  /// change; null for any other line, a call above all.
  static String? _renamable(String code) {
    if ((_type.firstMatch(code) ?? _provider.firstMatch(code))?.group(1)
        case final name?) {
      return name;
    }
    final member = _typedMember.firstMatch(code);
    if (member == null || _keywords.contains(member.namedGroup(_memberType))) {
      return null;
    }
    final declares =
        code.contains(_arrow) || _declarationEnds.any(code.endsWith);
    return declares ? member.namedGroup(_memberName) : null;
  }

  /// [code] without [name], its first use as a whole word, so the lines
  /// of a declaration renamed read alike.
  static String _unnamed(String code, String name) =>
      code.replaceFirst(RegExp('\\b${RegExp.escape(name)}\\b'), '\u0000');
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

  /// What starts a line of a new file's diff header.
  static const String _newMode = 'new file mode';

  /// What starts the lines naming the old and new sides of a file.
  static const List<String> _sideHeaders = ['--- ', '+++ '];

  /// What starts each part of a file's diff.
  static const String _hunkHeader = '@@';

  /// Whether the change deletes the file.
  bool isDeleted = false;

  /// Whether the change adds the file.
  bool isNew = false;

  /// The file's lines in the diff after its header.
  final List<_DiffLine> lines = [];

  /// The project-relative path of the file.
  final String path;

  /// The run of changed lines the next line is part of, a line unchanged
  /// starting another.
  int _block = 0;

  /// Whether the lines read are past the header, in the first part or
  /// after, where a line removed may start as the side headers do.
  bool _inParts = false;

  /// Whether the lines read last were removed, so the lines added next
  /// replace them.
  bool _replacing = false;

  /// The type the next line of the file before the change is in; null at
  /// the top level.
  String? _oldScope;

  /// The type the next line of the file after the change is in; null at
  /// the top level.
  String? _newScope;

  /// The lines the change adds, but those another section tells.
  List<String> get added => [
    for (final line in lines)
      if (line.isAdded && !line.isTold) line.text,
  ];

  /// The lines the change adds that replace none it removes, but those
  /// another section tells.
  List<String> get addedAnew => [
    for (final line in lines)
      if (line.isAdded && line.isAnew && !line.isTold) line.text,
  ];

  /// The lines the change adds or removes, each with its `+` or `-`, but
  /// those another section tells.
  List<String> get changed => [
    for (final line in lines)
      if ((line.isAdded || line.isRemoved) && !line.isTold) line.signed,
  ];

  /// The path, saying when the change deletes or adds the file.
  String get label => isDeleted
      ? '$path (deleted)'
      : isNew
      ? '$path (new)'
      : path;

  /// Reads [line], the next line of the file's diff.
  void read(String line) {
    if (line.startsWith(_hunkHeader)) _inParts = true;
    if (!_inParts) {
      if (line.startsWith(_deletedMode)) isDeleted = true;
      if (line.startsWith(_newMode)) isNew = true;
      if (_sideHeaders.any(line.startsWith)) return;
    }
    final diffLine = _DiffLine(line, block: _block, isAnew: !_replacing);
    if (line.startsWith(_hunkHeader)) {
      // Git ends the header with the line the part is in, as `class Foo {`
      _oldScope = _newScope = _scopeAfter(
        line
            .substring(line.lastIndexOf(_hunkHeader) + _hunkHeader.length)
            .trim(),
        null,
      );
    } else {
      if (!diffLine.isAdded) _oldScope = _scopeAfter(diffLine.text, _oldScope);
      if (!diffLine.isRemoved) {
        _newScope = _scopeAfter(diffLine.text, _newScope);
      }
    }
    diffLine.scope = diffLine.isRemoved ? _oldScope : _newScope;
    if (!diffLine.isAdded && !diffLine.isRemoved) _block++;
    if (!diffLine.isAdded) _replacing = diffLine.isRemoved;
    lines.add(diffLine);
  }

  /// The type the lines after [text] are in, [scope] the type [text] is
  /// in: a line starting at its start, but a comment, ends [scope], into
  /// the type it declares, if any.
  static String? _scopeAfter(String text, String? scope) {
    final code = text.trim();
    if (code.isEmpty || text.startsWith(' ') || text.startsWith('\t')) {
      return scope;
    }
    if (code.startsWith('//')) return scope;
    return CommitDigest._type.firstMatch(code)?.group(1);
  }
}

/// One line of a file's diff: added, removed, unchanged, or a header.
class _DiffLine {
  /// Reads [line], in the run of changed lines [block], added [isAnew]
  /// when no line removed comes right before it.
  _DiffLine(String line, {required this.block, required this.isAnew})
    : isAdded = line.startsWith(_addedSign),
      isRemoved = line.startsWith(_removedSign),
      text = _signs.any(line.startsWith) ? line.substring(1) : line;

  /// What starts a line added.
  static const String _addedSign = '+';

  /// What starts a line removed.
  static const String _removedSign = '-';

  /// What starts a line unchanged.
  static const String _unchangedSign = ' ';

  /// What starts a line added, removed or unchanged.
  static const List<String> _signs = [_addedSign, _removedSign, _unchangedSign];

  /// The run of changed lines the line is part of.
  final int block;

  /// Whether the line is added.
  final bool isAdded;

  /// Whether the line is added, replacing no line removed.
  final bool isAnew;

  /// Whether the line is removed.
  final bool isRemoved;

  /// Whether another section tells the line, moved or renamed, or it is
  /// only indented anew, so the changes section leaves it out.
  bool isTold = false;

  /// The file a line added moved from, when it moved unchanged.
  _FileDiff? movedFrom;

  /// The type the line is in, on its side of the change; null at the top
  /// level.
  String? scope;

  /// The line removed a line added moved from, when it moved unchanged.
  _DiffLine? twin;

  /// The line without its sign.
  final String text;

  /// The line without its sign nor the spaces around it.
  late final String code = text.trim();

  /// The line with its sign.
  String get signed => isAdded
      ? '$_addedSign$text'
      : isRemoved
      ? '$_removedSign$text'
      : text;
}
