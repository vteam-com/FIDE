part of 'class_splitter.dart';

/// A text range to delete from a file.
typedef _Removal = ({int offset, int end});

/// A directive line to add to a file; parts go after every other directive.
typedef _Insertion = ({String line, bool isPart});

/// Plans a [ClassSplitter] run over an overlay of the project, so every
/// step re-resolves the files as already changed, without touching disk.
class _Planner {
  _Planner({
    required String sdkPath,
    required String projectPath,
    required String filePath,
  }) : _filePath = filePath {
    _context = AnalysisContextCollection(
      includedPaths: [projectPath],
      resourceProvider: _provider,
      sdkPath: sdkPath,
    ).contextFor(filePath);
  }

  /// Key of the `dart:core` library, which every file imports implicitly.
  static final Uri _dartCore = Uri.parse('dart:core');

  final String _filePath;

  final OverlayResourceProvider _provider = OverlayResourceProvider(
    PhysicalResourceProvider.INSTANCE,
  );

  late final AnalysisContext _context;

  /// Planned content of every changed file.
  final Map<String, String> _changed = {};

  /// Files created by the plan, in split order.
  final List<String> _created = [];

  /// Compile errors of each changed file before the plan touched it; new
  /// files start at zero.
  final Map<String, int> _baselineErrors = {};

  int _modificationStamp = 0;

  /// Splits [_filePath] until one public class is left, then checks that
  /// no changed file gained compile errors.
  Future<ClassSplitResult> run() async {
    // Unresolved code (stale packages, broken imports) can't be split safely
    final existing = await _errorsIn(_filePath);
    if (existing.isNotEmpty) {
      throw ClassSplitException(
        '${p.basename(_filePath)} has ${existing.length} compile error(s); '
        'fix them, or run `flutter pub get`, and try again:\n'
        '${existing.first}',
      );
    }
    while (true) {
      final library = await _libraryContaining(_filePath);
      final unit = _unitAt(library, _filePath);
      final classes = unit.unit.declarations
          .whereType<ClassDeclaration>()
          .where((c) => !Identifier.isPrivateName(c.namePart.typeName.lexeme))
          .toList();
      if (classes.length <= 1) break;

      final stem = p.basenameWithoutExtension(_filePath);
      final keep = classes.firstWhere(
        (c) => _fileStemFor(c) == stem,
        orElse: () => classes.first,
      );
      final moving = classes.firstWhere((c) => c != keep);
      await _move(library, unit, [
        moving,
        ..._privateHelpersOf(library, unit, moving),
      ]);
    }
    if (_changed.isEmpty) {
      throw const ClassSplitException('The file already has one public class');
    }
    await _checkErrors();
    return ClassSplitResult(files: Map.of(_changed), createdFiles: _created);
  }

  /// `snake_case` file stem for [declaration]'s class.
  static String _fileStemFor(ClassDeclaration declaration) =>
      ProjectName.normalize(declaration.namePart.typeName.lexeme)!;

  /// Private declarations of [unit] that only [declaration] uses, directly
  /// or through each other, in source order, so they can leave the library
  /// with it; empty when the rest of the library uses any of them too.
  static List<CompilationUnitMember> _privateHelpersOf(
    ResolvedLibraryResult library,
    ResolvedUnitResult unit,
    ClassDeclaration declaration,
  ) {
    final group = <CompilationUnitMember>{declaration};
    final pending = <CompilationUnitMember>[declaration];
    while (pending.isNotEmpty) {
      for (final reference in _ReferenceCollector.collect(
        pending.removeLast(),
      )) {
        if (reference.top.library != library.element ||
            !reference.top.isPrivate) {
          continue;
        }
        final helper = _declarationOf(unit, reference.top);
        // Declared in another part of the library: it has to stay
        if (helper == null) return const [];
        if (group.add(helper)) pending.add(helper);
      }
    }
    final usedOutside =
        [
          for (final libraryUnit in library.units)
            ..._ReferenceCollector.collect(libraryUnit.unit, skip: group),
        ].any(
          (r) => r.top.isPrivate && group.contains(_declarationOf(unit, r.top)),
        );
    if (usedOutside) return const [];
    return group.skip(1).toList()..sort((a, b) => a.offset.compareTo(b.offset));
  }

  /// The top-level declaration of [unit] declaring [element], or null when
  /// another unit declares it or it has no name to locate it by.
  static CompilationUnitMember? _declarationOf(
    ResolvedUnitResult unit,
    Element element,
  ) {
    final declared = switch (element) {
      PropertyAccessorElement(isOriginVariable: true, :final variable) =>
        variable,
      _ => element,
    };
    final fragment = declared.firstFragment;
    final offset = fragment.nameOffset;
    if (offset == null ||
        fragment.libraryFragment?.source.fullName != unit.path) {
      return null;
    }
    return unit.unit.declarations
        .where((d) => d.offset <= offset && offset < d.end)
        .firstOrNull;
  }

  /// Moves [group], a class followed by the private declarations only it
  /// uses, out of [unit], a unit of [library].
  Future<void> _move(
    ResolvedLibraryResult library,
    ResolvedUnitResult unit,
    List<CompilationUnitMember> group,
  ) async {
    final declaration = group.first as ClassDeclaration;
    final moved = declaration.declaredFragment!.element;
    final libraryElement = library.element;
    final rootPath = libraryElement.firstFragment.source.fullName;
    final directory = p.dirname(unit.path);
    final inner = [
      for (final member in group) ..._ReferenceCollector.collect(member),
    ];
    final outer = [
      for (final libraryUnit in library.units)
        ..._ReferenceCollector.collect(libraryUnit.unit, skip: group.toSet()),
    ];

    bool isMoving(Element top) =>
        top == moved ||
        (top.library == libraryElement &&
            group.contains(_declarationOf(unit, top)));

    bool isOwnPrivate(_Reference r) =>
        r.top.library == libraryElement &&
        !isMoving(r.top) &&
        (r.top.isPrivate || r.element.isPrivate);

    // Imports the moved class resolves names through, by unit
    final needed = <(ResolvedUnitResult, ImportDirective)>[];
    var tangled =
        inner.any(isOwnPrivate) ||
        outer.any((r) => isMoving(r.top) && r.element.isPrivate);
    for (final reference in inner) {
      if (!reference.needsImport ||
          reference.top.library == libraryElement ||
          reference.top.library?.uri == _dartCore) {
        continue;
      }
      final provider = _importProviding(library, reference);
      if (provider == null) {
        // Can't tell which import brings the name in: keep library scope
        tangled = true;
      } else if (!needed.contains(provider)) {
        needed.add(provider);
      }
    }

    final stem = _fileStemFor(declaration);
    final newPath = tangled
        ? p.join(
            directory,
            '${p.basenameWithoutExtension(unit.path)}.$stem.dart',
          )
        : p.join(directory, '$stem.dart');
    if (_changed.containsKey(newPath) || File(newPath).existsSync()) {
      throw ClassSplitException(
        'Can\'t move ${moved.name}: ${p.basename(newPath)} already exists',
      );
    }

    final ranges = [for (final member in group) _declarationRange(unit, member)]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    final classText = [
      for (final range in ranges)
        unit.content.substring(range.offset, range.end).trim(),
    ].join('\n\n');
    final removals = <String, List<_Removal>>{unit.path: ranges};
    final insertions = <String, List<_Insertion>>{};
    void insert(String path, String line, {bool isPart = false}) => insertions
        .putIfAbsent(path, () => [])
        .add((line: line, isPart: isPart));

    final String newContent;
    if (tangled) {
      newContent =
          "part of '${_relativeUri(rootPath, newPath)}';\n\n$classText\n";
      insert(
        rootPath,
        "part '${_relativeUri(newPath, rootPath)}';",
        isPart: true,
      );
    } else {
      final header =
          [
            for (final (neededUnit, directive) in needed)
              _directiveFor(neededUnit, directive, newPath),
            if (inner.any(
              (r) =>
                  r.needsImport &&
                  r.top.library == libraryElement &&
                  !isMoving(r.top),
            ))
              "import '${_relativeUri(rootPath, newPath)}';",
          ]..sort(
            (a, b) => _uriOrder(_lineUri(a)).compareTo(_uriOrder(_lineUri(b))),
          );
      newContent = [
        if (header.isNotEmpty) '${header.join('\n')}\n',
        '$classText\n',
      ].join('\n');

      if (outer.any((r) => r.top == moved)) {
        insert(rootPath, "import '${_relativeUri(newPath, rootPath)}';");
      }
      // Imports only the moved class used are no longer needed here
      for (final (neededUnit, directive) in needed) {
        final stillUsed = outer.any(
          (r) => r.needsImport && _provides(directive, r),
        );
        if (!stillUsed) {
          removals
              .putIfAbsent(neededUnit.path, () => [])
              .add(_lineRange(neededUnit.content, directive));
        }
      }
      await _updateDependents(
        libraryElement,
        moved,
        rootPath,
        newPath,
        removals,
        insert,
      );
    }

    final edited = {...removals.keys, ...insertions.keys};
    // Read errors while the session still matches the files
    for (final path in edited) {
      if (!_baselineErrors.containsKey(path)) {
        _baselineErrors[path] = (await _errorsIn(path)).length;
      }
    }
    _baselineErrors[newPath] = 0;
    for (final path in edited) {
      _write(
        path,
        _edited(
          _changed[path] ?? File(path).readAsStringSync(),
          removals[path] ?? const [],
          insertions[path] ?? const [],
        ),
      );
    }
    _created.add(newPath);
    _write(newPath, newContent);
    await _context.applyPendingFileChanges();
  }

  /// Points every other library using [moved] through [rootPath] at
  /// [newPath]: importers get a matching import (dropping the old one once
  /// unused) and libraries re-exporting the file also export the new one.
  Future<void> _updateDependents(
    LibraryElement libraryElement,
    ClassElement moved,
    String rootPath,
    String newPath,
    Map<String, List<_Removal>> removals,
    void Function(String, String) insert,
  ) async {
    final rootName = p.basename(rootPath);
    final visited = <String>{
      for (final fragment in libraryElement.fragments) fragment.source.fullName,
    };
    for (final path in _context.contextRoot.analyzedFiles()) {
      if (!path.endsWith('.dart') || visited.contains(path)) continue;
      final content = _changed[path] ?? File(path).readAsStringSync();
      if (!content.contains(rootName) && !content.contains(moved.name!)) {
        continue;
      }
      final library = await _libraryContaining(path);
      for (final unit in library.units) {
        visited.add(unit.path);
      }

      final references = [
        for (final unit in library.units)
          ..._ReferenceCollector.collect(unit.unit),
      ];
      final usesMoved = references.any((r) => r.top == moved);
      for (final unit in library.units) {
        for (final directive in unit.unit.directives) {
          final NamespaceDirective namespaceDirective;
          final LibraryElement? target;
          switch (directive) {
            case ImportDirective(:final libraryImport?) when usesMoved:
              namespaceDirective = directive;
              target = libraryImport.importedLibrary;
            case ExportDirective(:final libraryExport?):
              namespaceDirective = directive;
              target = libraryExport.exportedLibrary;
            default:
              continue;
          }
          if (target != libraryElement ||
              !_namespaceHas(namespaceDirective, moved)) {
            continue;
          }
          final uri = _siblingUri(
            namespaceDirective.uri.stringValue!,
            rootPath,
            newPath,
          );
          if (namespaceDirective is ImportDirective) {
            final importDirective = namespaceDirective;
            final prefix = importDirective.prefix?.name;
            insert(
              unit.path,
              "import '$uri'${prefix == null ? '' : ' as $prefix'};",
            );
            final stillUsed = references.any(
              (r) =>
                  r.top != moved &&
                  r.needsImport &&
                  _provides(importDirective, r),
            );
            if (!stillUsed) {
              removals
                  .putIfAbsent(unit.path, () => [])
                  .add(_lineRange(unit.content, importDirective));
            }
          } else {
            insert(unit.path, "export '$uri';");
          }
        }
      }
    }
  }

  /// Throws when a changed file has more compile errors than before.
  Future<void> _checkErrors() async {
    await _context.applyPendingFileChanges();
    final problems = <String>[];
    for (final path in _changed.keys) {
      final errors = await _errorsIn(path);
      if (errors.length > (_baselineErrors[path] ?? 0)) {
        problems.add(errors.first);
      }
    }
    if (problems.isNotEmpty) {
      throw ClassSplitException(
        'Splitting would break the build, so nothing was changed:\n'
        '${problems.join('\n')}',
      );
    }
  }

  /// Compile errors currently reported for [path].
  Future<List<String>> _errorsIn(String path) =>
      compileErrors(_context.currentSession, path);

  /// Overlays [content] at [path] for the next analysis.
  void _write(String path, String content) {
    _changed[path] = content;
    _provider.setOverlay(
      path,
      content: content,
      modificationStamp: _modificationStamp++,
    );
    _context.changeFile(path);
  }

  /// The resolved library [path] belongs to.
  Future<ResolvedLibraryResult> _libraryContaining(String path) async {
    final result = await _context.currentSession.getResolvedLibraryContaining(
      path,
    );
    if (result is! ResolvedLibraryResult) {
      throw ClassSplitException(
        'Couldn\'t analyze ${p.basename(path)}; run `flutter pub get` first',
      );
    }
    return result;
  }

  /// The unit of [library] stored at [path].
  static ResolvedUnitResult _unitAt(
    ResolvedLibraryResult library,
    String path,
  ) => library.units.firstWhere((unit) => unit.path == path);

  /// The import of [library] that [reference] resolves through, with the
  /// unit declaring it, or null when none does.
  static (ResolvedUnitResult, ImportDirective)? _importProviding(
    ResolvedLibraryResult library,
    _Reference reference,
  ) {
    for (final unit in library.units) {
      for (final directive in unit.unit.directives) {
        if (directive is ImportDirective && _provides(directive, reference)) {
          return (unit, directive);
        }
      }
    }
    return null;
  }

  /// Whether [directive] brings [reference]'s declaration into scope under
  /// the prefix it was written with.
  static bool _provides(ImportDirective directive, _Reference reference) {
    return directive.prefix?.name == reference.prefix &&
        _namespaceHas(directive, reference.top);
  }

  /// Whether [directive]'s namespace includes [element].
  static bool _namespaceHas(NamespaceDirective directive, Element element) {
    final namespace = switch (directive) {
      ImportDirective(:final libraryImport) => libraryImport?.namespace,
      ExportDirective(:final libraryExport) =>
        libraryExport != null && _exportShows(libraryExport, element.name)
            ? libraryExport.exportedLibrary?.exportNamespace
            : null,
    };
    if (namespace == null) return false;
    return namespace.definedNames2.values.any(
      (e) =>
          e == element ||
          (e.name == element.name && e.library == element.library),
    );
  }

  /// Whether [export]'s `show` and `hide` combinators let [name] through.
  static bool _exportShows(LibraryExport export, String? name) {
    return export.combinators.every(
      (combinator) => switch (combinator) {
        ShowElementCombinator(:final shownNames) => shownNames.contains(name),
        HideElementCombinator(:final hiddenNames) => !hiddenNames.contains(
          name,
        ),
      },
    );
  }

  /// [directive]'s source as written for the file at [newPath], with a
  /// relative URI re-pointed from its own unit's folder.
  static String _directiveFor(
    ResolvedUnitResult unit,
    ImportDirective directive,
    String newPath,
  ) {
    final source = unit.content.substring(directive.offset, directive.end);
    final uri = directive.uri.stringValue!;
    if (Uri.parse(uri).hasScheme) return source;
    final target = p.normalize(p.join(p.dirname(unit.path), uri));
    final start = directive.uri.offset - directive.offset;
    return source.replaceRange(
      start,
      start + directive.uri.length,
      "'${_relativeUri(target, newPath)}'",
    );
  }

  /// Posix URI of [target] relative to the folder of [from].
  static String _relativeUri(String target, String from) =>
      p.posix.joinAll(p.split(p.relative(target, from: p.dirname(from))));

  /// [uri], which names [rootPath], re-pointed at [newPath].
  static String _siblingUri(String uri, String rootPath, String newPath) =>
      p.posix.normalize(
        p.posix.join(p.posix.dirname(uri), _relativeUri(newPath, rootPath)),
      );

  /// [declaration]'s text with its comments, from the line after the
  /// previous declaration or directive through the end of its last line.
  static _Removal _declarationRange(
    ResolvedUnitResult unit,
    CompilationUnitMember declaration,
  ) {
    final content = unit.content;
    final members = [...unit.unit.directives, ...unit.unit.declarations];
    final index = members.indexOf(declaration);
    final previous = index > 0 ? members[index - 1] : null;
    final offset = previous == null
        ? declaration.offset
        : _lineEndAfter(content, previous.end);
    return (offset: offset, end: _lineEndAfter(content, declaration.end));
  }

  /// [node]'s whole line or lines, through the line break.
  static _Removal _lineRange(String content, AstNode node) {
    final lineStart = content.lastIndexOf('\n', node.offset) + 1;
    return (offset: lineStart, end: _lineEndAfter(content, node.end));
  }

  /// Offset just past the line break at or after [offset].
  static int _lineEndAfter(String content, int offset) {
    final lineBreak = content.indexOf('\n', offset);
    return lineBreak == -1 ? content.length : lineBreak + 1;
  }

  /// [content] with [removals] cut, then [insertions] added after the
  /// existing directives of their kind.
  static String _edited(
    String content,
    List<_Removal> removals,
    List<_Insertion> insertions,
  ) {
    var result = content;
    for (final removal in [
      ...removals,
    ]..sort((a, b) => b.offset.compareTo(a.offset))) {
      result = result.replaceRange(removal.offset, removal.end, '');
    }
    for (final insertion in insertions) {
      result = _withDirective(result, insertion);
    }
    return result;
  }

  /// Sort key putting `dart:` URIs first, then `package:`, then relative
  /// ones, each alphabetically, as the `directives_ordering` lint expects.
  static String _uriOrder(String uri) {
    final group = uri.startsWith('dart:')
        ? _dartUriGroup
        : uri.startsWith('package:')
        ? _packageUriGroup
        : _relativeUriGroup;
    return '$group$uri';
  }

  static const String _dartUriGroup = '0';
  static const String _packageUriGroup = '1';
  static const String _relativeUriGroup = '2';

  /// The quoted URI in directive [line].
  static String _lineUri(String line) =>
      RegExp(r"'([^']*)'").firstMatch(line)?.group(1) ?? '';

  /// [content] with [insertion]'s line in URI order among the directives of
  /// its kind, else after the last directive it may follow, else at the top.
  static String _withDirective(String content, _Insertion insertion) {
    final directives = parseString(
      content: content,
      throwIfDiagnostics: false,
    ).unit.directives;
    if (!insertion.isPart) {
      final isExport = insertion.line.startsWith('export');
      final peers = directives
          .whereType<NamespaceDirective>()
          .where((d) => (d is ExportDirective) == isExport)
          .toList();
      final key = _uriOrder(_lineUri(insertion.line));
      final next = peers
          .where((d) => _uriOrder(d.uri.stringValue ?? '').compareTo(key) > 0)
          .firstOrNull;
      if (next != null) {
        return content.replaceRange(
          next.offset,
          next.offset,
          '${insertion.line}\n',
        );
      }
      if (peers.isNotEmpty) {
        return content.replaceRange(
          peers.last.end,
          peers.last.end,
          '\n${insertion.line}',
        );
      }
    }
    final anchor = insertion.isPart
        ? directives.lastOrNull
        : directives.where((d) => d is! PartDirective).lastOrNull;
    if (anchor != null) {
      return content.replaceRange(
        anchor.end,
        anchor.end,
        '\n${insertion.line}',
      );
    }
    final firstPart = directives.whereType<PartDirective>().firstOrNull;
    final offset = firstPart?.offset ?? 0;
    return content.replaceRange(offset, offset, '${insertion.line}\n\n');
  }
}
