part of 'class_splitter.dart';

/// A text range to delete from a file.
typedef _Removal = ({int offset, int end});

/// Plans a [ClassSplitter] run over an overlay of the project, so every
/// step re-resolves the files as already changed, without touching disk.
class _Planner {
  _Planner({
    required String sdkPath,
    required String projectPath,
    required this._filePath,
    required this._readFile,
  }) : _analysis = OverlayAnalysis(projectPath: projectPath, sdkPath: sdkPath);

  /// Key of the `dart:core` library, which every file imports implicitly.
  static final Uri _dartCore = Uri.parse('dart:core');

  final String _filePath;

  /// Reads a file's text from disk; see [ClassSplitter.readFile].
  final String Function(String path) _readFile;

  /// Text of each project file read from disk so far, each read once.
  final Map<String, String> _onDisk = {};

  /// The project's Dart files on disk, listed once, on first use.
  late final List<String> _dartFiles = [
    for (final path in _context.contextRoot.analyzedFiles())
      if (FileTypeUtils.isDartFile(path)) path,
  ];

  /// The project's analysis, with the planned files overlaid.
  final OverlayAnalysis _analysis;

  /// The context analyzing the file being split.
  late final AnalysisContext _context = _analysis.collection.contextFor(
    _filePath,
  );

  /// Planned content of every changed file.
  final Map<String, String> _changed = {};

  /// Files created by the plan, in split order.
  final List<String> _created = [];

  /// Compile errors of each changed file before the plan touched it; new
  /// files start at zero.
  final Map<String, int> _baselineErrors = {};

  /// Splits [_filePath] until one public class is left, then checks that
  /// no changed file gained compile errors.
  Future<ClassSplitResult> run() async {
    // Unresolved code (stale packages, broken imports) can't be split safely
    final existing = await _analysis.errorsIn(_filePath);
    if (existing.isNotEmpty) {
      throw ClassSplitException(
        '${p.basename(_filePath)} has '
        '${existing.length.count('compile error')}; '
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
      for (final reference in DartReferenceCollector.collect(
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
            ...DartReferenceCollector.collect(libraryUnit.unit, skip: group),
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
      for (final member in group) ...DartReferenceCollector.collect(member),
    ];
    final outer = [
      for (final libraryUnit in library.units)
        ...DartReferenceCollector.collect(
          libraryUnit.unit,
          skip: group.toSet(),
        ),
    ];

    bool isMoving(Element top) =>
        top == moved ||
        (top.library == libraryElement &&
            group.contains(_declarationOf(unit, top)));

    bool isOwnPrivate(DartReference r) =>
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
    // Directive lines to add to each file, placed by [withDirective]
    final insertions = <String, List<String>>{};
    void insert(String path, String line) =>
        insertions.putIfAbsent(path, () => []).add(line);

    final String newContent;
    if (tangled) {
      newContent =
          "part of '${relativeUriOf(rootPath, from: newPath)}';\n\n$classText\n";
      insert(rootPath, "part '${relativeUriOf(newPath, from: rootPath)}';");
    } else {
      final header = [
        for (final (neededUnit, directive) in needed)
          _directiveFor(neededUnit, directive, newPath),
        if (inner.any(
          (r) =>
              r.needsImport &&
              r.top.library == libraryElement &&
              !isMoving(r.top),
        ))
          "import '${relativeUriOf(rootPath, from: newPath)}';",
      ]..sort(compareDirectiveLines);
      newContent = [
        if (header.isNotEmpty) '${header.join('\n')}\n',
        '$classText\n',
      ].join('\n');

      if (outer.any((r) => r.top == moved)) {
        insert(rootPath, "import '${relativeUriOf(newPath, from: rootPath)}';");
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
        _baselineErrors[path] = (await _analysis.errorsIn(path)).length;
      }
    }
    _baselineErrors[newPath] = 0;
    for (final path in edited) {
      _write(
        path,
        _edited(
          _textOf(path),
          removals[path] ?? const [],
          insertions[path] ?? const [],
        ),
      );
    }
    _created.add(newPath);
    _write(newPath, newContent);
    await _analysis.applyChanges();
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
    // Files created by earlier moves may use the class too
    for (final path in {..._dartFiles, ..._created}) {
      if (visited.contains(path)) continue;
      final content = _textOf(path);
      if (!content.contains(rootName) && !content.contains(moved.name!)) {
        continue;
      }
      final library = await _libraryContaining(path);
      for (final unit in library.units) {
        visited.add(unit.path);
      }

      final references = [
        for (final unit in library.units)
          ...DartReferenceCollector.collect(unit.unit),
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
    await _analysis.applyChanges();
    await _analysis.checkNoNewErrors(
      _changed.keys,
      _baselineErrors,
      action: 'Splitting',
      failure: ClassSplitException.new,
    );
  }

  /// [path]'s planned content, else its text on disk, read at most once.
  String _textOf(String path) =>
      _changed[path] ?? _onDisk.putIfAbsent(path, () => _readFile(path));

  /// Overlays [content] at [path] for the next analysis.
  void _write(String path, String content) {
    _changed[path] = content;
    _analysis.overlay(path, content);
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
    DartReference reference,
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
  static bool _provides(ImportDirective directive, DartReference reference) {
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
    return namespace != null && defines(namespace.definedNames2, element);
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
      "'${relativeUriOf(target, from: newPath)}'",
    );
  }

  /// [uri], which names [rootPath], re-pointed at [newPath].
  static String _siblingUri(String uri, String rootPath, String newPath) =>
      p.posix.normalize(
        p.posix.join(
          p.posix.dirname(uri),
          relativeUriOf(newPath, from: rootPath),
        ),
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
        : TextOffsets.lineEndAfter(content, previous.end);
    return (
      offset: offset,
      end: TextOffsets.lineEndAfter(content, declaration.end),
    );
  }

  /// [node]'s whole line or lines, through the line break.
  static _Removal _lineRange(String content, AstNode node) => (
    offset: TextOffsets.lineStartOf(content, node.offset),
    end: TextOffsets.lineEndAfter(content, node.end),
  );

  /// [content] with [removals] cut, then the directive lines
  /// [insertions] added, each placed by [withDirective].
  static String _edited(
    String content,
    List<_Removal> removals,
    List<String> insertions,
  ) {
    var result = TextOffsets.applyEdits(content, {
      for (final removal in removals)
        removal.offset: (removal.end - removal.offset, ''),
    });
    for (final line in insertions) {
      result = withDirective(result, line);
    }
    return result;
  }
}
