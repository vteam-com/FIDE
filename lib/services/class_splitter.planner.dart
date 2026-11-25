part of 'class_splitter.dart';

/// A text range to delete from a file.
typedef _Removal = ({int offset, int end});

/// Plans a [ClassSplitter] run over an overlay of the project, so every
/// step re-resolves the files as already changed, without touching disk.
class _Planner {
  _Planner({
    required String sdkPath,
    required this._projectPath,
    required this._filePath,
    required this._readFile,
    required this._statesOnly,
  }) : _analysis = OverlayAnalysis(projectPath: _projectPath, sdkPath: sdkPath);

  /// The scheme of a package library's URI.
  static const String _packageScheme = 'package';

  /// The annotation saying a declaration is public only for tests.
  static const String _forTesting = 'visibleForTesting';

  /// The method of a stateful widget making its `State`.
  static const String _createState = 'createState';

  /// The line breaks ending a line and the blank line after it.
  static const int _blankLine = 2;

  /// Key of the `dart:core` library, which every file imports implicitly.
  static final Uri _dartCore = Uri.parse('dart:core');

  final String _filePath;

  /// The project's folder.
  final String _projectPath;

  /// Reads a file's text from disk; see [ClassSplitter.readFile].
  final String Function(String path) _readFile;

  /// Whether only the widgets' `State`s are tidied, no class split off;
  /// see [ClassSplitter.plan].
  final bool _statesOnly;

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

  /// The widget `State`s the plan made private, by their public name.
  final List<String> _privatized = [];

  /// The widget `State`s the plan moved beside their widget, by name.
  final List<String> _gathered = [];

  /// The part files the plan emptied, to delete, each by the file that
  /// took in what it held.
  final Map<String, String> _merged = {};

  /// How many statements reaching into a widget's `State` the plan removed
  /// from each test file, by path.
  final Map<String, int> _cleanedTests = {};

  /// The methods the plan moved out of each widget `State`, which tests
  /// called, by the `State`'s name.
  final Map<String, List<String>> _movedOut = {};

  /// Compile errors of each changed file before the plan touched it; new
  /// files start at zero.
  final Map<String, int> _baselineErrors = {};

  /// Moves each widget's `State` beside it, from the part file holding
  /// it, removes, when [_statesOnly], every reach into it from the tests,
  /// and makes it private, unless another library uses it; then,
  /// unless [_statesOnly], splits [_filePath] until one public class is
  /// left besides such `State`s, each staying with its widget; then checks
  /// that no changed file gained compile errors.
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
    await _gatherStates();
    if (_statesOnly) await _cleanTests();
    // Public States other libraries use, which stay public by their
    // widget; tests reaching into one are flagged by the Widget States
    // check, as making it private would break them
    final settled = <String>{};
    while (true) {
      final library = await _libraryContaining(_filePath);
      final unit = _unitAt(library, _filePath);
      final classes = unit.unit.declarations
          .whereType<ClassDeclaration>()
          .where((c) => !Identifier.isPrivateName(c.namePart.typeName.lexeme))
          .toList();
      final states = classes
          .where((c) => WidgetStates.isState(c.declaredFragment!.element))
          .toList();
      final tidied = [
        for (final state in states)
          if (!_isLeftAlone(unit, state)) state,
      ];
      final state = await _nextPrivatizable(library, tidied, settled);
      if (state != null) {
        await _privatize(library, state);
        continue;
      }
      final splittable = classes.where((c) => !states.contains(c)).toList();
      if (_statesOnly || splittable.length <= 1) break;

      final stem = p.basenameWithoutExtension(_filePath);
      final keep = splittable.firstWhere(
        (c) => _fileStemFor(c) == stem,
        orElse: () => splittable.first,
      );
      final moving = splittable.firstWhere((c) => c != keep);
      _checkNoSharedState(moving, states);
      await _move(library, unit, [
        moving,
        ..._privateHelpersOf(library, unit, moving),
      ]);
    }
    if (_changed.isEmpty) {
      throw ClassSplitException(
        _statesOnly
            ? 'Its widgets\' States are beside them already, and private '
                  'unless other files use them'
            : 'The file already has one public class',
      );
    }
    await _checkErrors();
    await _checkLayers();
    return ClassSplitResult(
      files: Map.of(_changed),
      createdFiles: _created,
      privatizedStates: _privatized,
      gatheredStates: _gathered,
      mergedFiles: _merged,
      cleanedTests: _cleanedTests,
      movedOutOfStates: _movedOut,
    );
  }

  /// Throws when [widget], about to leave its file, has one of [states],
  /// public as another library uses it, which would have to go with it.
  static void _checkNoSharedState(
    ClassDeclaration widget,
    List<ClassDeclaration> states,
  ) {
    final element = widget.declaredFragment!.element;
    for (final state in states) {
      if (WidgetStates.widgetOf(state.declaredFragment!.element) == element) {
        throw ClassSplitException(
          'Can\'t move ${element.name}: other files use its State, '
          '${state.namePart.typeName.lexeme}, which goes with it; '
          'move the two together',
        );
      }
    }
  }

  /// Moves the `State` of each widget [_filePath] declares from the other
  /// unit of the library holding it, a part file, right after its widget,
  /// as the `State` is part of it. A part file left without declarations
  /// goes, with its `part` directive: [_merged] records it.
  Future<void> _gatherStates() async {
    final library = await _libraryContaining(_filePath);
    final unit = _unitAt(library, _filePath);
    final widgets = {
      for (final declaration
          in unit.unit.declarations.whereType<ClassDeclaration>())
        declaration.declaredFragment!.element: declaration,
    };
    // Text edits by path: what replaces how many characters at an offset
    final edits = <String, Map<int, (int, String)>>{};
    void edit(String path, int offset, int length, String text) =>
        (edits[path] ??= {}).update(
          offset,
          (earlier) => (earlier.$1 + length, earlier.$2 + text),
          ifAbsent: () => (length, text),
        );
    for (final other in library.units) {
      if (other.path == _filePath) continue;
      final declarations = other.unit.declarations;
      var moved = 0;
      for (final state in declarations.whereType<ClassDeclaration>()) {
        final widget =
            widgets[WidgetStates.widgetOf(state.declaredFragment!.element)];
        if (widget == null || _isLeftAlone(other, state)) continue;
        final range = _declarationRange(other, state);
        edit(other.path, range.offset, range.end - range.offset, '');
        edit(
          _filePath,
          widget.end,
          0,
          '\n\n${other.content.substring(range.offset, range.end).trim()}',
        );
        _gathered.add(state.namePart.typeName.lexeme);
        moved++;
      }
      final part = moved == declarations.length && moved > 0
          ? _partDirectiveOf(library, other.path)
          : null;
      if (part != null) {
        final (holder, directive) = part;
        final line = _lineRange(holder.content, directive);
        edit(holder.path, line.offset, line.end - line.offset, '');
        edits.remove(other.path);
        _merged[other.path] = _filePath;
      }
    }
    if (edits.isEmpty) return;
    for (final MapEntry(key: path, value: changes) in edits.entries) {
      if (!_baselineErrors.containsKey(path)) {
        _baselineErrors[path] = (await _analysis.errorsIn(path)).length;
      }
      _write(
        path,
        TextOffsets.applyEdits(_unitAt(library, path).content, changes),
      );
    }
    await _analysis.applyChanges();
  }

  /// Removes every reach into the `State`s of the widgets [_filePath]
  /// declares from the project's tests, outside `lib`, as a widget's
  /// `State` is private to its widget (see [_TestCleaner]); first moves out
  /// of each `State` the methods tests call that use nothing of it (see
  /// [_PureMethods]), so the tests call them directly. A `State` an
  /// `// ignore: fcheck_widget_state` comment leaves alone is kept.
  Future<void> _cleanTests() async {
    final lib = p.join(_projectPath, ProjectPaths.libFolder);
    final unit = _unitAt(await _libraryContaining(_filePath), _filePath);
    // Each State by name, with its widget's, which a test may name alone
    final names = {
      for (final declaration
          in unit.unit.declarations.whereType<ClassDeclaration>())
        if (WidgetStates.widgetOf(declaration.declaredFragment!.element)
            case final widget? when !_isLeftAlone(unit, declaration))
          declaration.namePart.typeName.lexeme: widget.name!,
    };
    for (final MapEntry(key: name, value: widget) in names.entries) {
      final tests = [
        for (final path in _dartFiles)
          if (!p.isWithin(lib, path) &&
              (_textOf(path).contains(name) || _textOf(path).contains(widget)))
            path,
      ];
      // Resolved again after each change, as are their elements
      Future<InterfaceElement> stateNow() async =>
          (await _libraryContaining(_filePath)).element.getClass(name)!;

      final called = <String>{};
      for (final path in tests) {
        final state = await stateNow();
        for (final test in (await _libraryContaining(path)).units) {
          called.addAll(_TestCleaner(test, state).calledMethods());
        }
      }
      final movedOut = called.isEmpty
          ? const <String>{}
          : await _moveOutPure(name, called);

      for (final path in tests) {
        final state = await stateNow();
        for (final test in (await _libraryContaining(path)).units) {
          final (:removals, :statements) = _TestCleaner(
            test,
            state,
            movedOut: movedOut,
          ).plan();
          if (removals.isEmpty) continue;
          if (!_baselineErrors.containsKey(test.path)) {
            _baselineErrors[test.path] = (await _analysis.errorsIn(test.path))
                .length;
          }
          _write(
            test.path,
            TextOffsets.applyEdits(test.content, {
              for (final removal in removals)
                removal.offset: (removal.end - removal.offset, ''),
            }),
          );
          _cleanedTests.update(
            test.path,
            (count) => count + statements,
            ifAbsent: () => statements,
          );
          await _analysis.applyChanges();
        }
      }
    }
  }

  /// Moves out of the `State` named [name], declared in [_filePath], the
  /// methods among [called] that use nothing of it, as top-level functions
  /// (see [_PureMethods]); returns those it moved.
  Future<Set<String>> _moveOutPure(String name, Set<String> called) async {
    final unit = _unitAt(await _libraryContaining(_filePath), _filePath);
    final state = unit.unit.declarations
        .whereType<ClassDeclaration>()
        .firstWhere(
          (declaration) => declaration.namePart.typeName.lexeme == name,
        );
    final (:moved, :edits) = _PureMethods(unit, state).plan(called);
    if (moved.isEmpty) return moved;
    if (!_baselineErrors.containsKey(unit.path)) {
      _baselineErrors[unit.path] = (await _analysis.errorsIn(unit.path)).length;
    }
    _write(unit.path, TextOffsets.applyEdits(unit.content, edits));
    _movedOut[name] = [...?_movedOut[name], ...moved];
    await _analysis.applyChanges();
    return moved;
  }

  /// The unit of [library] holding the `part` directive naming the part
  /// file at [path], with it; null when none names it by a relative URI.
  static (ResolvedUnitResult, PartDirective)? _partDirectiveOf(
    ResolvedLibraryResult library,
    String path,
  ) {
    for (final unit in library.units) {
      for (final directive in unit.unit.directives.whereType<PartDirective>()) {
        final uri = directive.uri.stringValue;
        if (uri != null &&
            !uri.contains(':') &&
            p.normalize(p.join(p.dirname(unit.path), uri)) == path) {
          return (unit, directive);
        }
      }
    }
    return null;
  }

  /// The next of [states], a unit's public widget `State`s, to make
  /// private, as no library but [library] uses it; null when each is
  /// [settled], or found to be and added there, as another library uses
  /// it.
  Future<ClassDeclaration?> _nextPrivatizable(
    ResolvedLibraryResult library,
    List<ClassDeclaration> states,
    Set<String> settled,
  ) async {
    for (final state in states) {
      final name = state.namePart.typeName.lexeme;
      if (settled.contains(name)) continue;
      if ((await _usersOf(library, state.declaredFragment!.element)).isEmpty) {
        return state;
      }
      settled.add(name);
    }
    return null;
  }

  /// Whether [state], a widget's `State` in [unit], is left as it is by
  /// an `// ignore: fcheck_widget_state` comment, as the Widget States
  /// check leaves it: one ending its line, or among the comments its file
  /// starts with.
  static bool _isLeftAlone(ResolvedUnitResult unit, ClassDeclaration state) =>
      ParsedSourceFile(
        unit.path,
        unit.content,
        ignoreName: WidgetStates.ignoreName,
      ).isIgnoredAt(state);

  /// Whether [annotation] is `@visibleForTesting`, prefixed or not.
  static bool _isForTesting(Annotation annotation) =>
      annotation.name.name.split('.').last == _forTesting;

  /// Makes [state], a widget's public `State` only [library] uses,
  /// private: `_FooState` wherever the library names it, its own doc
  /// comment included, without the `@visibleForTesting` it no longer
  /// needs, its widget's `createState` declaring its base, `State<Foo>`.
  Future<void> _privatize(
    ResolvedLibraryResult library,
    ClassDeclaration state,
  ) async {
    final element = state.declaredFragment!.element;
    final name = element.name!;
    final privateName = WidgetStates.privateNameOf(name);
    if (library.element.getClass(privateName) != null) {
      throw ClassSplitException(
        'Can\'t make $name private: the library has a $privateName already',
      );
    }
    final declared = state.namePart.typeName.offset;
    final base = state.extendsClause!.superclass.toSource();
    for (final unit in library.units) {
      // A widget's `createState` declares the `State`'s base, as Flutter's
      // do, so the widget's API names no private type
      final returnTypes = [
        for (final method in _MethodFinder.of(unit.unit, _createState))
          if (method.returnType case final NamedType type
              when type.element == element)
            type,
      ];
      final offsets = {
        for (final use in NameUses.usesOf(element, unit, renaming: true))
          if (!returnTypes.any(
            (type) => type.offset <= use.offset && use.offset < type.end,
          ))
            use.offset,
        if (state.root == unit.unit) declared,
      };
      if (offsets.isEmpty && returnTypes.isEmpty) continue;
      if (!_baselineErrors.containsKey(unit.path)) {
        _baselineErrors[unit.path] = (await _analysis.errorsIn(unit.path))
            .length;
      }
      _write(
        unit.path,
        TextOffsets.applyEdits(unit.content, {
          for (final offset in offsets) offset: (name.length, privateName),
          for (final type in returnTypes) type.offset: (type.length, base),
          // Private, it needs no mark of being public for tests
          if (state.root == unit.unit)
            for (final annotation in state.metadata)
              if (_isForTesting(annotation))
                annotation.offset: (
                  annotation.endToken.next!.offset - annotation.offset,
                  '',
                ),
          // Its own doc comment names it as it is now called
          if (state.root == unit.unit)
            for (final token
                in state.documentationComment?.tokens ?? const <Token>[])
              for (final match in RegExp(
                '\\b${RegExp.escape(name)}\\b',
              ).allMatches(token.lexeme))
                token.offset + match.start: (name.length, privateName),
        }),
      );
    }
    _privatized.add(name);
    await _analysis.applyChanges();
  }

  /// The libraries other than [library] using [element], by the path of
  /// the file defining each.
  Future<Set<String>> _usersOf(
    ResolvedLibraryResult library,
    ClassElement element,
  ) async {
    final own = {
      for (final fragment in library.element.fragments)
        fragment.source.fullName,
    };
    final name = element.name!;
    final users = <String>{};
    for (final path in {..._dartFiles, ..._created}) {
      if (own.contains(path) ||
          _merged.containsKey(path) ||
          !_textOf(path).contains(name)) {
        continue;
      }
      final other = await _libraryContaining(path);
      for (final unit in other.units) {
        own.add(unit.path);
      }
      if (other.units.any(
        (unit) =>
            DartReferenceCollector.collect(unit.unit)
                .any((reference) => reference.top == element),
      )) {
        users.add(other.units.first.path);
      }
    }
    return users;
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

    // The class's file and the library importing each other would be a
    // cycle fCheck's Layers check reports: a part file needs no import
    final usesLibrary = inner.any(
      (r) =>
          r.needsImport && r.top.library == libraryElement && !isMoving(r.top),
    );
    final usedByLibrary = outer.any((r) => r.top == moved);
    if (usesLibrary && usedByLibrary) tangled = true;

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
        if (usesLibrary) "import '${relativeUriOf(rootPath, from: newPath)}';",
      ]..sort(compareDirectiveLines);
      newContent = [
        if (header.isNotEmpty) '${header.join('\n')}\n',
        '$classText\n',
      ].join('\n');

      if (usedByLibrary) {
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
      if (visited.contains(path) || _merged.containsKey(path)) continue;
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

  /// Throws when the changed files add a Layers issue fCheck would report
  /// for `lib`, such as files or folders depending on each other.
  Future<void> _checkLayers() async {
    final lib = p.join(_projectPath, ProjectPaths.libFolder);
    final relative = ProjectPaths(_projectPath).relativeOf;
    final package = (await _libraryContaining(_filePath)).element.uri;
    final packageName = package.isScheme(_packageScheme)
        ? package.pathSegments.first
        : null;
    final before = ImportGraph.parse({
      // The files as they are, without those the split creates
      for (final path in _dartFiles)
        if (p.isWithin(lib, path) && !_created.contains(path))
          relative(path): _onDisk.putIfAbsent(path, () => _readFile(path)),
    }, packageName: packageName);
    final after = before.updated({
      for (final MapEntry(key: path, value: content) in _changed.entries)
        if (p.isWithin(lib, path)) relative(path): content,
    }, packageName: packageName);
    final added = ImportGraph.compareIssues(
      before.layerIssues,
      after.layerIssues,
    ).added;
    if (added.isNotEmpty) {
      throw ClassSplitException(
        'Splitting would add a Layers issue fCheck reports: '
        '${added.first.message}',
      );
    }
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

  /// [range], whole lines of [content], with the blank line after it too
  /// when one is before it, so removing it leaves one blank line, not two.
  static _Removal _tidied(String content, _Removal range) {
    final blankBefore =
        range.offset >= _blankLine &&
        content[range.offset - 1] == '\n' &&
        content[range.offset - _blankLine] == '\n';
    final blankAfter = range.end < content.length && content[range.end] == '\n';
    return blankBefore && blankAfter
        ? (offset: range.offset, end: range.end + 1)
        : range;
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
