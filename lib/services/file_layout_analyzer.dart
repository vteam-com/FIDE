import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/import_graph.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/services/parsed_source_file.dart';
import 'package:fide/services/widget_creation.dart';
import 'package:path/path.dart' as p;

part 'file_layout_analyzer.creations.dart';
part 'file_layout_analyzer.library.dart';

/// Finds the files of a Flutter project's `lib` folder outside the folder
/// their kind belongs in, reading its Dart code without resolving it, as
/// fCheck's analyzers do:
///
/// - a view, a screen or page: a widget building a `Scaffold`, itself or
///   through a project widget wrapping one around the widget it takes,
///   or one the app opens as a route, belongs in `lib/views`;
/// - a pure widget: a file declaring only widgets and their states that
///   reads no app state, importing no state management package, nor
///   through the project files it imports, belongs in `lib/widgets`;
/// - a model: a file declaring plain Dart types (enums, classes holding
///   data) that imports only plain Dart libraries, itself and through the
///   project files it imports, without async code, belongs in
///   `lib/models`.
///
/// A file already in a folder named for its kind, at any depth (such as
/// a feature's own `widgets` folder), stays, as do the app's entry point,
/// the files building the app widget and the localizations. So does a
/// file whose leading comments say `// ignore: fcheck_file_layout`, or
/// whose main type starts on a line ending with it.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class FileLayoutAnalyzer {
  /// Creates a stateless analyzer.
  const FileLayoutAnalyzer();

  /// The name an `// ignore:` comment gives to skip the analyzer, in
  /// fCheck's naming.
  static const String ignoreName = 'fcheck_file_layout';

  /// The app widgets, built by the files that stay at the top of `lib`.
  static const Set<String> _apps = {
    'CupertinoApp',
    'MaterialApp',
    'WidgetsApp',
  };

  /// The one Flutter library plain Dart types may import, for
  /// `@immutable` and collection equality.
  static const String _flutterFoundation = 'package:flutter/foundation.dart';

  /// The classes that make a class a notifier holding state, not a model.
  static const Set<String> _notifiers = {
    'ChangeNotifier',
    'Listenable',
    'ValueListenable',
    'ValueNotifier',
  };

  /// The Dart libraries plain Dart types may import.
  static const Set<String> _plainDartLibraries = {
    'dart:collection',
    'dart:convert',
    'dart:core',
    'dart:math',
    'dart:typed_data',
  };

  /// The packages plain Dart types may import: annotations, value
  /// equality, immutable collections and text helpers, none doing I/O or
  /// holding state.
  static const Set<String> _plainDartPackages = {
    'built_collection',
    'built_value',
    'collection',
    'dart_mappable',
    'equatable',
    'fast_immutable_collections',
    'fixnum',
    'freezed_annotation',
    'intl',
    'json_annotation',
    'meta',
    'path',
    'quiver',
    'uuid',
  };

  /// A widget's name saying it is a screen: `HomeScreen`, `SettingsPage`.
  static final RegExp _screenName = RegExp(r'(?:Screen|Page)$');

  /// A file name saying it holds a view: `home_screen`, `accounts_view`.
  static final RegExp _viewFile = RegExp(r'_(?:page|screen|view)$');

  /// A widget's name saying it is a view: `HomeScreen`, `SettingsPage`,
  /// `AccountsView`, `ViewAccounts`.
  static final RegExp _viewName = RegExp(r'(?:Page|Screen|View)$|^View[A-Z]');

  /// The widgets a screen is built on.
  static const Set<String> _scaffolds = {
    'CupertinoPageScaffold',
    'CupertinoTabScaffold',
    'Scaffold',
  };

  /// The packages reading or holding app state.
  static const Set<String> _statePackages = {
    'async_redux',
    'bloc',
    'flutter_bloc',
    'flutter_mobx',
    'flutter_redux',
    'flutter_riverpod',
    'flutter_solidart',
    'get',
    'get_it',
    'hooks_riverpod',
    'hydrated_bloc',
    'mobx',
    'provider',
    'redux',
    'replay_bloc',
    'riverpod',
    'riverpod_annotation',
    'signals',
    'signals_flutter',
    'solidart',
    'stacked',
    'states_rebuilder',
    'watch_it',
  };

  /// Suffix of the superclasses making a class a widget's state, written
  /// with the widget as type argument: `State<Foo>`, `ConsumerState<Foo>`.
  static const String _stateSuffix = 'State';

  /// Suffix of the superclasses making a class a widget, such as
  /// `StatelessWidget`, and of the field types taking one, such as
  /// `Widget?` or `PreferredSizeWidget`.
  static const String _widgetSuffix = 'Widget';

  /// Reviews the `lib` folder of the project at [projectPath]; synchronous,
  /// so run it off the UI thread.
  FileLayoutReview analyze(String projectPath) {
    final libPath = p.join(projectPath, ProjectPaths.libFolder);
    final packageName = _packageName(projectPath);
    final files = {
      for (final file in ParsedSourceFile.readAll(
        libPath,
        ignoreName: ignoreName,
      ))
        file.path: file,
    };
    final libraries = {
      for (final file in files.values)
        if (!file.unit.directives.any((d) => d is PartOfDirective))
          file.path: _Library(
            file,
            files: files,
            projectPath: projectPath,
            packageName: packageName,
          ),
    };
    final kinds = _Kinds(libraries.values);
    final readsState = _tainted(
      libraries,
      (library) => library.externalUris.any(_isStatePackage),
    );
    final notPlainDart = _tainted(
      libraries,
      (library) =>
          library.hasAsync ||
          library.externalUris.any((uri) => !_isPlainDart(uri)) ||
          library.classes.any(kinds.isWidgetOrState),
    );
    final skipped = [
      for (final directory in CodeCategory.localization.directories)
        p.join(projectPath, directory),
    ];

    final moves = <FileMove>[];
    for (final MapEntry(key: path, value: library) in libraries.entries) {
      if (skipped.any((folder) => p.isWithin(folder, path))) continue;
      final relative = library.relativePath;
      final placed = _placeOf(
        library,
        kinds,
        readsState: readsState.contains(path),
        isPlainDart: !notPlainDart.contains(path),
        isInViews: FileLayoutReview.isPlaced(CodeCategory.views, relative),
      );
      if (placed == null) continue;
      final (:category, :main) = placed;
      if (FileLayoutReview.isPlaced(category, relative)) continue;
      final ownUnit = identical(main.root, library.file.unit);
      if (ownUnit ? library.file.isIgnoredAt(main) : library.file.isIgnored) {
        continue;
      }
      moves.add(
        FileMove(
          category: category,
          path: relative,
          target: p.posix.join(
            FileLayoutReview.targetOf(category),
            p.posix.basename(relative),
          ),
          name: _Library.typeNameOf(main)!,
          line: ownUnit ? library.file.lineOf(main) : 1,
          parts: [
            for (final part in library.parts) _relative(projectPath, part),
          ],
        ),
      );
    }
    final candidates = FileLayoutReview(
      moves: _withBlockers(projectPath, moves),
      fileCount: libraries.length,
      packageName: packageName,
      // Parts are files of the graph too, as fCheck's
      graph: ImportGraph({
        for (final library in libraries.values) ...{
          library.relativePath: ImportGraph.dependenciesIn(
            library.relativePath,
            library.file.unit,
            packageName: packageName,
          ),
          for (final part in library.parts)
            _relative(projectPath, part): const <String>{},
        },
      }),
      parts: {
        for (final library in libraries.values)
          if (library.parts.isNotEmpty)
            library.relativePath: [
              for (final part in library.parts) _relative(projectPath, part),
            ],
      },
    );
    final movable = [
      for (final move in candidates.moves)
        if (move.blocker == null) move,
    ];
    final plans = Map.fromIterables(movable, candidates.planEach(movable));
    final planned = [
      for (final move in candidates.moves)
        if (plans[move] case final plan?) _planned(move, plan) else move,
    ];
    return FileLayoutReview(
      moves: planned,
      fileCount: candidates.fileCount,
      packageName: packageName,
      graph: candidates.graph,
      parts: candidates.parts,
      allPlans: {
        for (final category in FileLayoutReview.categories)
          if ([
                for (final move in planned)
                  if (move.category == category && move.canMove) move,
              ]
              case final moves when moves.isNotEmpty)
            category: candidates.planAll(moves),
      },
    );
  }

  /// [move] as [plan], its plan made alone, has it: with the files moved
  /// along, the Layers issues it fixes, or the one it would add.
  static FileMove _planned(FileMove move, FileLayoutPlan plan) => FileMove(
    category: move.category,
    path: move.path,
    target: move.target,
    name: move.name,
    line: move.line,
    parts: move.parts,
    along: plan.addedIssue == null ? plan.moves.skip(1).toList() : const [],
    fixedIssues: plan.fixedIssues,
    addedIssue: plan.addedIssue,
  );

  /// The kind of [library] and its main type, the one the file is named
  /// after, else its first; null when its kind is none the review places:
  /// the app's entry point or widget, or a file mixing kinds.
  ///
  /// A file declaring a screen is a view; one declaring only widgets and
  /// their states, none [readsState], a widget, unless it [isInViews] and
  /// its name or a widget's says it is a view (`accounts_view.dart`,
  /// `ViewAccounts`); one declaring a type holding data, and no notifier
  /// nor class of static members only, all [isPlainDart], a model.
  static ({CodeCategory category, CompilationUnitMember main})? _placeOf(
    _Library library,
    _Kinds kinds, {
    required bool readsState,
    required bool isPlainDart,
    required bool isInViews,
  }) {
    if (library.declaresMain || library.created.any(_apps.contains)) {
      return null;
    }
    final types = library.publicTypes.toList();
    final classes = types.whereType<ClassDeclaration>().toList();
    final widgets = classes.where(kinds.isWidget).toList();
    final screens = widgets.where(kinds.isScreen).toList();
    final stem = p.basenameWithoutExtension(library.file.path);
    CompilationUnitMember mainOf(List<CompilationUnitMember> declared) =>
        declared
            .where(
              (declaration) =>
                  ProjectName.normalize(_Library.typeNameOf(declaration)!) ==
                  stem,
            )
            .firstOrNull ??
        declared.first;

    if (screens.isNotEmpty) {
      return (category: CodeCategory.views, main: mainOf(screens));
    }
    final namesView =
        _viewFile.hasMatch(stem) ||
        widgets.any((widget) => _viewName.hasMatch(_Kinds._nameOf(widget)));
    if (widgets.isNotEmpty &&
        !readsState &&
        !(isInViews && namesView) &&
        classes.every(kinds.isWidgetOrState)) {
      return (category: CodeCategory.widgets, main: mainOf(widgets));
    }
    final models = types.where(_isModelType).toList();
    if (isPlainDart &&
        models.isNotEmpty &&
        !classes.any((c) => _isNamespace(c) || _isNotifier(c))) {
      return (category: CodeCategory.models, main: mainOf(models));
    }
    return null;
  }

  /// [moves], each blocked when a file it writes is there already or
  /// another move writes it too.
  static List<FileMove> _withBlockers(
    String projectPath,
    List<FileMove> moves,
  ) {
    final writers = <String, int>{};
    for (final move in moves) {
      for (final target in move.paths.values) {
        writers.update(target, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    String? blockerOf(FileMove move) {
      for (final target in move.paths.values) {
        if (File(p.joinAll([projectPath, ...p.posix.split(target)]))
            .existsSync()) {
          return '$target already exists';
        }
        if (writers[target]! > 1) {
          return '${writers[target]} files would move to $target';
        }
      }
      return null;
    }

    final ordered = [
      for (final category in FileLayoutReview.categories)
        ...moves.where((move) => move.category == category).toList()
          ..sort((a, b) => a.path.compareTo(b.path)),
    ];
    return [
      for (final move in ordered)
        FileMove(
          category: move.category,
          path: move.path,
          target: move.target,
          name: move.name,
          line: move.line,
          parts: move.parts,
          blocker: blockerOf(move),
        ),
    ];
  }

  /// Whether [declaration] is a type holding data: an enum, an extension
  /// type, or a class with instance fields, or with no members besides
  /// its constructors (a sealed base, a primary constructor's class); an
  /// interface of methods only is behavior, not data.
  static bool _isModelType(CompilationUnitMember declaration) =>
      switch (declaration) {
        EnumDeclaration() || ExtensionTypeDeclaration() => true,
        ClassDeclaration(body: ClassBody(:final members)) =>
          members.any(
                (member) => member is FieldDeclaration && !member.isStatic,
              ) ||
              members.every((member) => member is ConstructorDeclaration),
        _ => false,
      };

  /// Whether [declaration] only groups static members, as constants and
  /// helpers do.
  static bool _isNamespace(ClassDeclaration declaration) {
    final members = declaration.body.members;
    final isStatic = [
      for (final member in members)
        if (member
            case FieldDeclaration(:final isStatic) ||
                MethodDeclaration(:final isStatic))
          isStatic,
    ];
    return isStatic.isNotEmpty && isStatic.every((each) => each);
  }

  /// Whether [declaration] is a notifier, holding state for listeners.
  static bool _isNotifier(ClassDeclaration declaration) => [
    ?declaration.extendsClause?.superclass,
    ...?declaration.withClause?.mixinTypes,
    ...?declaration.implementsClause?.interfaces,
  ].any((type) => _notifiers.contains(type.name.lexeme));

  /// Whether the library at [uri] is plain Dart.
  static bool _isPlainDart(String uri) =>
      uri == _flutterFoundation ||
      _plainDartLibraries.contains(uri) ||
      _plainDartPackages.contains(_packageOf(uri));

  /// Whether the library at [uri] is a state management package's.
  static bool _isStatePackage(String uri) =>
      _statePackages.contains(_packageOf(uri));

  /// The package of the `package:` [uri]; null for another URI.
  static String? _packageOf(String uri) => uri.startsWith(packageScheme)
      ? uri.substring(packageScheme.length).split('/').first
      : null;

  /// The package name of the project at [projectPath], from its pubspec;
  /// null without one.
  static String? _packageName(String projectPath) {
    final pubspec = File(ProjectPaths(projectPath).pubspec);
    return pubspec.existsSync()
        ? Pubspec.parse(pubspec.readAsStringSync()).name
        : null;
  }

  /// [path] relative to [projectPath], with `/` separators.
  static String _relative(String projectPath, String path) =>
      p.posix.joinAll(p.split(p.relative(path, from: projectPath)));

  /// The paths of [libraries] that [isTainted] accepts, or that import or
  /// export one of them or a project file not read, at any depth.
  static Set<String> _tainted(
    Map<String, _Library> libraries,
    bool Function(_Library library) isTainted,
  ) {
    final importers = <String, List<String>>{};
    for (final MapEntry(key: path, value: library) in libraries.entries) {
      for (final dependency in library.dependencies) {
        importers.putIfAbsent(dependency, () => []).add(path);
      }
    }
    final tainted = {
      for (final MapEntry(key: path, value: library) in libraries.entries)
        if (isTainted(library) ||
            library.dependencies.any((d) => !libraries.containsKey(d)))
          path,
    };
    final pending = [...tainted];
    while (pending.isNotEmpty) {
      for (final importer in importers[pending.removeLast()] ?? const []) {
        if (tainted.add(importer)) pending.add(importer);
      }
    }
    return tainted;
  }
}

/// The project's widgets, their states and its screens, by class name,
/// from the classes of all its libraries.
class _Kinds {
  _Kinds(Iterable<_Library> libraries) {
    final classes = [for (final library in libraries) ...library.classes];
    widgets = _subclasses(
      classes,
      (type) => type.name.lexeme.endsWith(FileLayoutAnalyzer._widgetSuffix),
    );
    states = _subclasses(
      classes,
      (type) =>
          type.typeArguments != null &&
          type.name.lexeme.endsWith(FileLayoutAnalyzer._stateSuffix),
    );

    // What each widget builds, itself and through its states
    final builds = <String, Set<String>>{};
    final takesWidget = <String>{};
    for (final declaration in classes) {
      final name = _nameOf(declaration);
      final String? widget;
      if (widgets.contains(name)) {
        widget = name;
        if (_takesWidget(declaration)) takesWidget.add(name);
      } else if (states.contains(name)) {
        widget = switch (declaration
            .extendsClause
            ?.superclass
            .typeArguments
            ?.arguments
            .firstOrNull) {
          NamedType(:final name) => name.lexeme,
          _ => null,
        };
      } else {
        widget = null;
      }
      if (widget != null) {
        builds.putIfAbsent(widget, () => {}).addAll(_Creations.of(declaration));
      }
    }

    // A widget taking one to wrap a scaffold around is a scaffold too
    final scaffolds = {...FileLayoutAnalyzer._scaffolds};
    var grew = true;
    while (grew) {
      grew = false;
      for (final name in takesWidget) {
        if (!scaffolds.contains(name) &&
            builds[name]!.any(scaffolds.contains)) {
          scaffolds.add(name);
          grew = true;
        }
      }
    }
    final routes = {for (final library in libraries) ...library.routes};
    screens = {
      for (final name in widgets)
        if (!takesWidget.contains(name) &&
            (routes.contains(name) ||
                FileLayoutAnalyzer._screenName.hasMatch(name) ||
                (builds[name]?.any(scaffolds.contains) ?? false)))
          name,
    };
  }

  /// The widgets that are screens: taking no widget to show, they are
  /// built on a scaffold, opened as a route or named as one.
  late final Set<String> screens;

  /// The classes that are a widget's state.
  late final Set<String> states;

  /// The classes that are widgets.
  late final Set<String> widgets;

  /// Whether [declaration] is a screen.
  bool isScreen(ClassDeclaration declaration) =>
      screens.contains(_nameOf(declaration));

  /// Whether [declaration] is a widget.
  bool isWidget(ClassDeclaration declaration) =>
      widgets.contains(_nameOf(declaration));

  /// Whether [declaration] is a widget or a widget's state.
  bool isWidgetOrState(ClassDeclaration declaration) {
    final name = _nameOf(declaration);
    return widgets.contains(name) || states.contains(name);
  }

  /// The class [declaration] declares.
  static String _nameOf(ClassDeclaration declaration) =>
      declaration.namePart.typeName.lexeme;

  /// The names of [classes] extending a class [isBase] accepts, directly
  /// or through others of them.
  static Set<String> _subclasses(
    List<ClassDeclaration> classes,
    bool Function(NamedType superclass) isBase,
  ) {
    final names = <String>{};
    var grew = true;
    while (grew) {
      grew = false;
      for (final declaration in classes) {
        final superclass = declaration.extendsClause?.superclass;
        if (superclass != null &&
            (isBase(superclass) || names.contains(superclass.name.lexeme)) &&
            names.add(_nameOf(declaration))) {
          grew = true;
        }
      }
    }
    return names;
  }

  /// Whether [declaration] has a field taking a widget, or a builder of
  /// one, to show: `Widget child`, `List<Widget> actions`, `WidgetBuilder`.
  static bool _takesWidget(ClassDeclaration declaration) =>
      declaration.body.members.any(
        (member) =>
            member is FieldDeclaration &&
            !member.isStatic &&
            (member.fields.type?.toSource().contains(
                  FileLayoutAnalyzer._widgetSuffix,
                ) ??
                false),
      );
}
