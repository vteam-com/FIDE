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
/// unless another library names it, through a `GlobalKey<FooState>` or a
/// test's `tester.state<FooState>(…)`.
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
    final namesUsed = {
      for (final file in files) file.path: _TypeNames.of(file.unit),
    };
    final findings = <WidgetStateFinding>[];
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
      if (file.isIgnoredAt(declaration)) continue;

      final state = _nameOf(declaration);
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
      final namedElsewhere = namesUsed.entries.any(
        (used) => libraryOf[used.key] != library && used.value.contains(state),
      );
      if (!Identifier.isPrivateName(state) && !namedElsewhere) {
        findings.add(finding(WidgetStateProblem.public));
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

/// Collects the names of the types a unit writes: `FooState` in
/// `GlobalKey<FooState>` or `tester.state<FooState>(…)`.
class _TypeNames extends RecursiveAstVisitor<void> {
  final Set<String> _names = {};

  /// The names of the types [unit] writes.
  static Set<String> of(CompilationUnit unit) {
    final collector = _TypeNames();
    unit.accept(collector);
    return collector._names;
  }

  @override
  void visitNamedType(NamedType node) {
    _names.add(node.name.lexeme);
    super.visitNamedType(node);
  }
}
