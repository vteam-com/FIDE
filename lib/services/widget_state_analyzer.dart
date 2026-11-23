import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/widget_state_report.dart';
import 'package:fide/services/parsed_source_file.dart';
import 'package:path/path.dart' as p;

/// Finds the `State` classes of a Flutter project's stateful widgets that
/// stray from Flutter's convention, reading its Dart code without
/// resolving it, as fCheck's analyzers do.
///
/// A stateful widget is two classes: the widget, and the `State` its
/// `createState` makes, which is part of the widget, not a class of its
/// own. So the `State` lives beside its widget, in the widget's file, not
/// in a part file or a file of its own, and is private (`_FooState`),
/// unless another library of the app names it, through a
/// `GlobalKey<FooState>`. No test reaches into it,
/// `tester.state<FooState>(…)`: a test checks the widget itself, through
/// what it shows and the callbacks it calls, so each test line reaching
/// into a `State` is a finding of its own, one naming a private `State`,
/// which can't compile, too.
///
/// A `State` whose line, or whose file's leading comments, say
/// `// ignore: fcheck_widget_state` is left alone.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class WidgetStateAnalyzer {
  /// Creates a stateless analyzer.
  const WidgetStateAnalyzer();

  /// The name an `// ignore:` comment gives to skip the analyzer, in
  /// fCheck's naming.
  static const String ignoreName = 'fcheck_widget_state';

  /// The folders besides `lib` whose files may name a `State`.
  static const List<String> _otherFolders = [
    ProjectPaths.testFolder,
    'integration_test',
    'test_driver',
  ];

  /// The classes a widget with a `State` extends: Flutter's, Riverpod's
  /// and flutter_hooks'.
  static const Set<String> _statefulWidgets = {
    'StatefulWidget',
    'ConsumerStatefulWidget',
    'StatefulHookWidget',
    'StatefulHookConsumerWidget',
  };

  /// The classes a widget's `State` extends, with the widget as type
  /// argument: Flutter's and Riverpod's.
  static const Set<String> _states = {'State', 'ConsumerState'};

  /// Reviews the project at [projectPath]; synchronous, so run it off the
  /// UI thread.
  WidgetStateReport analyze(String projectPath) {
    final lib = ParsedSourceFile.readAll(
      p.join(projectPath, ProjectPaths.libFolder),
      ignoreName: ignoreName,
    );
    final files = [
      ...lib,
      for (final folder in _otherFolders)
        ...ParsedSourceFile.readAll(
          p.join(projectPath, folder),
          ignoreName: ignoreName,
        ),
    ];
    final libraryOf = _librariesOf(files);
    final classes = <_Class>[
      for (final file in lib)
        for (final declaration
            in file.unit.declarations.whereType<ClassDeclaration>())
          (file: file, declaration: declaration),
    ];
    final superclassOf = {
      for (final (file: _, :declaration) in classes)
        if (declaration.extendsClause case final extendsClause?)
          _nameOf(declaration): extendsClause.superclass.name.lexeme,
    };
    bool extendsOne(String name, Set<String> bases) {
      final seen = <String>{};
      String? current = name;
      while (current != null && seen.add(current)) {
        if (bases.contains(current)) return true;
        current = superclassOf[current];
      }
      return false;
    }

    final classesNamed = <String, List<_Class>>{};
    for (final entry in classes) {
      (classesNamed[_nameOf(entry.declaration)] ??= []).add(entry);
    }
    final typesUsed = {
      for (final file in files) file.path: _TypeUses.of(file.unit),
    };
    final namesUsed = {
      for (final MapEntry(key: path, value: types) in typesUsed.entries)
        path: {for (final type in types) type.name.lexeme},
    };
    final tests = files.skip(lib.length);
    final findings = <WidgetStateFinding>[];
    // The States a test may name, each with its widget and its file: a
    // private one too, which no test can reach, so it doesn't compile
    final statesNamed = <String, ({String widget, String widgetPath})>{};
    var stateCount = 0;
    for (final (:file, :declaration) in classes) {
      final superclass = declaration.extendsClause?.superclass;
      final widgetName =
          switch (superclass?.typeArguments?.arguments.firstOrNull) {
            NamedType(:final name) => name.lexeme,
            _ => null,
          };
      if (superclass == null ||
          widgetName == null ||
          !extendsOne(superclass.name.lexeme, _states)) {
        continue;
      }
      final library = libraryOf[file.path];
      final widgets = extendsOne(widgetName, _statefulWidgets)
          ? classesNamed[widgetName] ?? const <_Class>[]
          : const <_Class>[];
      final widget =
          widgets
              .where((candidate) => libraryOf[candidate.file.path] == library)
              .firstOrNull ??
          widgets.firstOrNull;
      if (widget == null) continue;
      stateCount++;
      final state = _nameOf(declaration);
      statesNamed[state] = (widget: widgetName, widgetPath: widget.file.path);
      if (file.isIgnoredAt(declaration)) continue;

      WidgetStateFinding finding(WidgetStateProblem problem) =>
          WidgetStateFinding(
            problem: problem,
            path: file.path,
            line: file.lineOf(declaration),
            state: state,
            widget: widgetName,
            widgetPath: widget.file.path,
            isInWidgetLibrary: libraryOf[widget.file.path] == library,
          );
      if (widget.file.path != file.path) {
        findings.add(finding(WidgetStateProblem.apart));
      }
      if (Identifier.isPrivateName(state)) continue;
      bool namedIn(Iterable<ParsedSourceFile> files) => files.any(
        (other) =>
            libraryOf[other.path] != library &&
            namesUsed[other.path]!.contains(state),
      );
      // One only tests name is theirs to stop reaching into: flagged there
      if (!namedIn(lib) && !namedIn(tests)) {
        findings.add(finding(WidgetStateProblem.public));
      }
    }
    for (final test in tests) {
      final lines = <int>{};
      for (final type in typesUsed[test.path]!) {
        final state = statesNamed[type.name.lexeme];
        final line = test.lineOf(type);
        if (state == null || test.isIgnoredAt(type) || !lines.add(line)) {
          continue;
        }
        findings.add(
          WidgetStateFinding(
            problem: WidgetStateProblem.reachedByTest,
            path: test.path,
            line: line,
            state: type.name.lexeme,
            widget: state.widget,
            widgetPath: state.widgetPath,
            isInWidgetLibrary: false,
          ),
        );
      }
    }
    return WidgetStateReport(findings: findings, stateCount: stateCount);
  }

  /// The library each of [files] belongs to, by path: its own, or, for a
  /// part file, the file naming it in a `part` directive.
  static Map<String, String> _librariesOf(List<ParsedSourceFile> files) {
    final libraryOf = {for (final file in files) file.path: file.path};
    for (final file in files) {
      for (final directive in file.unit.directives.whereType<PartDirective>()) {
        final uri = directive.uri.stringValue;
        if (uri == null || uri.contains(':')) continue;
        libraryOf[p.normalize(p.join(p.dirname(file.path), uri))] = file.path;
      }
    }
    return libraryOf;
  }

  /// The class [declaration] declares.
  static String _nameOf(ClassDeclaration declaration) =>
      declaration.namePart.typeName.lexeme;
}

/// A class of the project: its declaration, in its file.
typedef _Class = ({ParsedSourceFile file, ClassDeclaration declaration});

/// Collects the types a unit writes: `FooState` in `GlobalKey<FooState>`
/// or `tester.state<FooState>(…)`.
class _TypeUses extends RecursiveAstVisitor<void> {
  final List<NamedType> _types = [];

  /// The types [unit] writes, in source order.
  static List<NamedType> of(CompilationUnit unit) {
    final collector = _TypeUses();
    unit.accept(collector);
    return collector._types;
  }

  @override
  void visitNamedType(NamedType node) {
    _types.add(node);
    super.visitNamedType(node);
  }
}
