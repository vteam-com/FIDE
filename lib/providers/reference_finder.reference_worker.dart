part of 'reference_finder.dart';

/// A declaration the outline lists, resolved: its node, element and name.
typedef _Target = ({
  ResolvedUnitResult unit,
  Declaration declaration,
  Element element,
  String name,
});

/// The [ReferenceFinder] side running in the background isolate: one
/// project analysis answering requests in turn.
///
/// Files are read through an overlay so a rename can be checked against the
/// analysis before anything is written.
class _ReferenceWorker {
  _ReferenceWorker(String projectPath, String sdkPath) {
    _collection = AnalysisContextCollection(
      includedPaths: [projectPath],
      resourceProvider: _provider,
      sdkPath: sdkPath,
    );
  }

  /// Characters a Dart identifier may hold, not starting with a digit.
  static final RegExp _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

  late final AnalysisContextCollection _collection;

  /// Last seen modification time of each analyzed Dart file.
  final Map<String, DateTime> _modified = {};

  final OverlayResourceProvider _provider = OverlayResourceProvider(
    PhysicalResourceProvider.INSTANCE,
  );

  /// Completes when the requests received so far are answered.
  Future<void> _queue = Future.value();

  int _modificationStamp = 0;

  /// Isolate entry: sends a request port through `args.$1`, then answers
  /// each `(filePath, line, column, newName, replyPort)` request: with the
  /// `List<SearchResult>` uses when `newName` is null, else with the
  /// renamed files' `Map<String, String>` contents; or an error message.
  static void main((SendPort, String, String) args) {
    final (ready, projectPath, sdkPath) = args;
    final worker = _ReferenceWorker(projectPath, sdkPath);
    final requests = ReceivePort();
    ready.send(requests.sendPort);
    requests.listen((message) {
      final (filePath, line, column, newName, reply) =
          message as (String, int, int, String?, SendPort);
      worker._queue = worker._queue.then((_) async {
        try {
          await worker._refresh();
          final target = await worker._targetAt(filePath, line, column);
          reply.send(
            newName == null
                ? await worker._find(target)
                : await worker._rename(target, newName),
          );
        } catch (e) {
          reply.send('$e');
        }
      });
    });
  }

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
    await _checkCompiles(renamed);
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
    var result = content;
    for (final offset in offsets.toList()..sort((a, b) => b.compareTo(a))) {
      result = result.replaceRange(offset, offset + length, replacement);
    }
    return result;
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
  /// of their files more compile errors than it has now.
  Future<void> _checkCompiles(Map<String, String> contents) async {
    final before = {
      for (final path in contents.keys) path: (await _errorsIn(path)).length,
    };
    final problems = <String>[];
    try {
      _overlay(contents);
      await _applyChanges();
      for (final path in contents.keys) {
        final errors = await _errorsIn(path);
        if (errors.length > before[path]!) problems.add(errors.first);
      }
    } finally {
      for (final path in contents.keys) {
        _provider.removeOverlay(path);
        _collection.contextFor(path).changeFile(path);
      }
      await _applyChanges();
    }
    if (problems.isNotEmpty) {
      throw StateError(
        'Renaming would break the build, so nothing was changed:\n'
        '${problems.join('\n')}',
      );
    }
  }

  /// Overlays each of [contents] for the next analysis.
  void _overlay(Map<String, String> contents) {
    for (final MapEntry(key: path, value: content) in contents.entries) {
      _provider.setOverlay(
        path,
        content: content,
        modificationStamp: _modificationStamp++,
      );
      _collection.contextFor(path).changeFile(path);
    }
  }

  /// Compile errors [path] has in the current analysis.
  Future<List<String>> _errorsIn(String path) =>
      compileErrors(_collection.contextFor(path).currentSession, path);

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
    // Private names can only be used inside their library
    final candidates = element.isPrivate
        ? [
            for (final fragment in element.library!.fragments)
              fragment.source.fullName,
          ]
        : _modified.keys.where(
            (path) => File(path).readAsStringSync().contains(target.name),
          );
    final declaration = target.declaration;
    final uses = <String, ({String content, List<_Use> uses})>{};
    for (final path in candidates) {
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

  /// Tells the analysis about Dart files added, changed or deleted since
  /// the last request.
  Future<void> _refresh() async {
    final seen = <String>{};
    for (final context in _collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        seen.add(path);
        final modified = File(path).lastModifiedSync();
        final previous = _modified[path];
        _modified[path] = modified;
        if (previous != null && previous != modified) context.changeFile(path);
      }
    }
    for (final path in _modified.keys.toList()) {
      if (seen.contains(path)) continue;
      _modified.remove(path);
      _collection.contextFor(path).changeFile(path);
    }
    await _applyChanges();
  }

  /// Lets every context take in the files marked changed.
  Future<void> _applyChanges() async {
    for (final context in _collection.contexts) {
      await context.applyPendingFileChanges();
    }
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
