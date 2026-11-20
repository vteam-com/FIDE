part of 'reference_finder.dart';

/// A declaration the outline lists, resolved: its node, element and name.
typedef _Target = ({
  ResolvedUnitResult unit,
  Declaration declaration,
  Element element,
  String name,
});

/// The worker's reply to a [ReferenceRequest]: its [answer], or the
/// [error] message it failed with.
typedef _ReferenceReply = ({Object? answer, String? error});

/// The [ReferenceFinder] side running in the background isolate: one
/// project analysis answering requests in turn.
///
/// Files are read through an overlay so a rename can be checked against the
/// analysis before anything is written.
class _ReferenceWorker {
  _ReferenceWorker(this._projectPath, String sdkPath)
    : _analysis = OverlayAnalysis(projectPath: _projectPath, sdkPath: sdkPath);

  /// A whole Dart identifier.
  static final RegExp _identifier = RegExp('^$identifierPattern\$');

  /// The project's analysis, with a change being checked overlaid.
  final OverlayAnalysis _analysis;

  /// The project's analysis contexts.
  AnalysisContextCollection get _collection => _analysis.collection;

  /// The analyzed Dart files, with their modification times and text.
  final FileTexts _files = FileTexts();

  /// Counts the requests received of each kind that only the latest of
  /// is answered (see [ReferenceRequest.isLatestOnly]), so a queued one can
  /// tell a newer one came.
  final Map<Type, int> _latest = {};

  /// The analyzed project's folder: what it calls elsewhere isn't listed.
  final String _projectPath;

  /// Completes when the requests received so far are answered.
  Future<void> _queue = Future.value();

  /// Isolate entry: sends a request port through `args.$1`, then answers
  /// each `(request, replyPort)` with a [_ReferenceReply] holding the
  /// [ReferenceRequest]'s answer, or the error message instead; a request
  /// a newer one of its kind replaced while it waited answers
  /// [ReferenceFinder.superseded] (see [ReferenceRequest.isLatestOnly]).
  static void main((SendPort, String, String) args) {
    final (ready, projectPath, sdkPath) = args;
    final worker = _ReferenceWorker(projectPath, sdkPath);
    final requests = ReceivePort();
    ready.send(requests.sendPort);
    requests.listen((message) {
      final (request, reply) = message as (ReferenceRequest<Object?>, SendPort);
      final kind = request.runtimeType;
      final ticket = request.isLatestOnly
          ? worker._latest.update(kind, (count) => count + 1, ifAbsent: () => 1)
          : null;
      worker._queue = worker._queue.then((_) async {
        if (ticket != null && ticket != worker._latest[kind]) {
          reply.send((answer: null, error: ReferenceFinder.superseded));
          return;
        }
        _ReferenceReply response;
        try {
          await worker._refresh();
          response = (answer: await worker._answer(request), error: null);
        } catch (e) {
          response = (answer: null, error: '$e');
        }
        reply.send(response);
      });
    });
  }

  /// The answer to [request].
  Future<Object?> _answer(ReferenceRequest<Object?> request) async =>
      switch (request) {
        FindReferencesRequest(:final filePath, :final line, :final column) =>
          await _find(await _targetAt(filePath, line, column)),
        CalleesRequest(:final filePath, :final line, :final column) => _callees(
          await _targetAt(filePath, line, column),
        ),
        DefinitionRequest(:final filePath, :final offset, :final content) =>
          await _definition(filePath, offset, content),
        RenameRequest(
          :final filePath,
          :final line,
          :final column,
          :final newName,
        ) =>
          await _rename(await _targetAt(filePath, line, column), newName),
        LookupFieldRequest(:final filePath, :final offset) =>
          await _lookupField(filePath, offset, {}),
        LookupFieldsRequest(:final sites) => await _lookupFields(sites),
        CheckCompilesRequest(:final contents, :final action) =>
          await _checkCompiles(contents, action).then((_) => null),
      };

  /// See [ReferenceFinder.find].
  Future<List<SearchResult>> _find(_Target target) async {
    final uses = await _usesOf(target, renaming: false);
    return [
      for (final fileUses in uses.values)
        for (final use in fileUses.uses) use.result,
    ]..sort(
      (a, b) => a.filePath != b.filePath
          ? a.filePath.compareTo(b.filePath)
          : a.lineNumber != b.lineNumber
          ? a.lineNumber.compareTo(b.lineNumber)
          : a.matchStart.compareTo(b.matchStart),
    );
  }

  /// See [ReferenceFinder.callees].
  List<SearchResult> _callees(_Target target) => [
    for (final callee in _CalleeVisitor.calleesOf(target.declaration))
      if (!_UsageVisitor.same(callee, target.element)) ?_declarationOf(callee),
  ];

  /// See [ReferenceFinder.definition].
  Future<SearchResult> _definition(
    String filePath,
    int offset,
    String content,
  ) async {
    if (!p.isWithin(_projectPath, filePath)) {
      throw StateError('${p.basename(filePath)} isn\'t in the project');
    }
    // Unsaved edits are analyzed as the file, so the offset lands on them
    final edited = content == _analysis.read(filePath)
        ? const <String, String>{}
        : {filePath: content};
    return _overlaid(edited, () async {
      final unit = await _resolvedUnit(filePath);
      if (unit == null) throw StateError('Can\'t analyze $filePath');
      final element = _NameLocator.elementAt(unit.unit, offset);
      if (element == null) throw StateError('No name to go to at the caret');
      final place = _declarationOf(element);
      if (place != null) return place;
      final library = element.library?.uri;
      throw StateError(
        '${element.displayName} is declared outside the project'
        '${library == null ? '' : ', in $library'}',
      );
    });
  }

  /// Where [element] is declared, as a place in the code naming it (its
  /// class for an implicit constructor, its field for an implicit getter
  /// or setter); null when the project doesn't declare it.
  SearchResult? _declarationOf(Element element) {
    final declared = switch (element) {
      ConstructorElement(isOriginDeclaration: false, :final enclosingElement) =>
        enclosingElement,
      PropertyAccessorElement(isOriginDeclaration: false, :final variable) =>
        variable,
      _ => element,
    };
    final fragment = declared.firstFragment;
    final library = fragment.libraryFragment;
    final path = library?.source.fullName;
    if (library == null || path == null || !p.isWithin(_projectPath, path)) {
      return null;
    }
    final nameOffset = fragment.nameOffset;
    return _UsageVisitor.resultAt(
      path,
      _analysis.read(path),
      library.lineInfo,
      nameOffset ?? fragment.offset,
      // An unnamed constructor's place has no name to mark
      nameOffset == null ? 0 : declared.name?.length ?? 0,
    );
  }

  /// See [ReferenceFinder.rename].
  Future<Map<String, String>> _rename(_Target target, String newName) async {
    if (!_identifier.hasMatch(newName)) {
      throw ArgumentError('"$newName" isn\'t a valid Dart name');
    }
    if (newName == target.name) return const {};

    // Every use, plus the declaration's own name
    final offsets = {
      for (final MapEntry(key: path, value: fileUses) in (await _usesOf(
        target,
        renaming: true,
      )).entries)
        path: (
          content: fileUses.content,
          offsets: {for (final use in fileUses.uses) use.offset},
        ),
    };
    final declared = target.unit.path;
    offsets.putIfAbsent(
      declared,
      () => (content: target.unit.content, offsets: <int>{}),
    );
    offsets[declared]!.offsets.add(_nameOffset(target.declaration));

    final renamed = {
      for (final MapEntry(key: path, value: file) in offsets.entries)
        path: _replaced(
          file.content,
          file.offsets,
          target.name.length,
          newName,
        ),
    };
    await _checkCompiles(renamed, 'Renaming');
    return renamed;
  }

  /// [content] with the [length] characters at each of [offsets] replaced
  /// by [replacement].
  static String _replaced(
    String content,
    Set<int> offsets,
    int length,
    String replacement,
  ) {
    return TextOffsets.applyEdits(content, {
      for (final offset in offsets) offset: (length, replacement),
    });
  }

  /// Where [declaration]'s name starts.
  static int _nameOffset(Declaration declaration) => switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.offset,
    FunctionDeclaration(:final name) => name.offset,
    MethodDeclaration(:final name) => name.offset,
    VariableDeclaration(:final name) => name.offset,
    _ => throw StateError('Can\'t rename a ${declaration.runtimeType}'),
  };

  /// Throws, leaving the analysis as it was, when [contents] would give any
  /// of their files more compile errors than it has now; [action] names
  /// the change in the message.
  Future<void> _checkCompiles(
    Map<String, String> contents,
    String action,
  ) async {
    final before = await _analysis.errorCounts(contents.keys);
    await _overlaid(
      contents,
      () => _analysis.checkNoNewErrors(contents.keys, before, action: action),
    );
  }

  /// What [body] answers with [contents] analyzed as their files' text;
  /// the files on disk are analyzed again afterwards, even when it throws.
  Future<T> _overlaid<T>(
    Map<String, String> contents,
    Future<T> Function() body,
  ) async {
    try {
      contents.forEach(_analysis.overlay);
      await _analysis.applyChanges();
      return await body();
    } finally {
      contents.keys.forEach(_analysis.removeOverlay);
      await _analysis.applyChanges();
    }
  }

  /// The outline declaration starting at 1-based [line] and [column] of
  /// [filePath]; throws when there is none (e.g. unsaved edits moved it),
  /// since no count beats a wrong zero.
  Future<_Target> _targetAt(String filePath, int line, int column) async {
    final unit = await _resolvedUnit(filePath);
    if (unit == null) throw StateError('Can\'t analyze $filePath');
    final offset = unit.lineInfo.getOffsetOfLine(line - 1) + column - 1;
    final declaration = _UsageVisitor.declarationAt(unit.unit, offset);
    final element = declaration?.declaredFragment?.element;
    final name = element?.name;
    if (declaration == null || element == null || name == null) {
      throw StateError('No declaration at $line:$column of $filePath');
    }
    return (unit: unit, declaration: declaration, element: element, name: name);
  }

  /// [target]'s uses in each file that has some, with the file's content.
  ///
  /// [renaming] includes the uses inside the declaration itself and, for a
  /// field, its `this.` parameters and their named arguments.
  Future<Map<String, ({String content, List<_Use> uses})>> _usesOf(
    _Target target, {
    required bool renaming,
  }) async {
    final element = target.element;
    final declaration = target.declaration;
    final uses = <String, ({String content, List<_Use> uses})>{};
    for (final path in _candidatePaths(element, target.name)) {
      final unit = await _resolvedUnit(path);
      if (unit == null) continue;
      final fileUses = _UsageVisitor.usesOf(
        element,
        unit,
        renaming: renaming,
        skip: !renaming && path == target.unit.path
            ? (offset: declaration.offset, end: declaration.end)
            : null,
      );
      if (fileUses.isNotEmpty) {
        uses[path] = (content: unit.content, uses: fileUses);
      }
    }
    return uses;
  }

  /// The files that may use [element], named [name]: its library's for a
  /// private name, else every analyzed file mentioning [name], read only
  /// when it changed since an earlier request.
  Iterable<String> _candidatePaths(Element element, String name) =>
      element.isPrivate
      ? [
          for (final fragment in element.library!.fragments)
            fragment.source.fullName,
        ]
      : _files.mentioning(name);

  /// Tells the analysis about Dart files added, changed or deleted since
  /// the last request.
  Future<void> _refresh() async {
    final seen = <String>{};
    for (final context in _collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!FileTypeUtils.isDartFile(path)) continue;
        seen.add(path);
        if (_files.update(path, File(path).lastModifiedSync())) {
          context.changeFile(path);
        }
      }
    }
    for (final path in _files.paths.toList()) {
      if (seen.contains(path)) continue;
      _files.remove(path);
      _collection.contextFor(path).changeFile(path);
    }
    await _analysis.applyChanges();
  }

  /// [path] resolved, or null when it can't be.
  Future<ResolvedUnitResult?> _resolvedUnit(String path) async {
    final AnalysisContext context;
    try {
      context = _collection.contextFor(path);
    } on StateError {
      return null;
    }
    final result = await context.currentSession.getResolvedUnit(path);
    return result is ResolvedUnitResult ? result : null;
  }
}
