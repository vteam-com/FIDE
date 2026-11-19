import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

/// Compile errors [session] reports for [path], each as
/// `file:line: message`, for refactorings to compare before and after.
Future<List<String>> compileErrors(AnalysisSession session, String path) async {
  final result = await session.getErrors(path);
  if (result is! ErrorsResult) return const [];
  return [
    for (final diagnostic in result.diagnostics)
      if (diagnostic.severity == Severity.error)
        '${p.basename(path)}:'
            '${result.lineInfo.getLocation(diagnostic.offset).lineNumber}: '
            '${diagnostic.message}',
  ];
}

/// A project's analysis reading files through an overlay, so a
/// refactoring's planned edits are analyzed, and checked not to break the
/// build, before anything is written to disk.
class OverlayAnalysis {
  /// Analyzes the project at [projectPath] against the Dart SDK at
  /// [sdkPath].
  OverlayAnalysis({required String projectPath, required String sdkPath}) {
    collection = AnalysisContextCollection(
      includedPaths: [projectPath],
      resourceProvider: _provider,
      sdkPath: sdkPath,
    );
  }

  /// The project's analysis contexts.
  late final AnalysisContextCollection collection;

  final OverlayResourceProvider _provider = OverlayResourceProvider(
    PhysicalResourceProvider.INSTANCE,
  );

  int _modificationStamp = 0;

  /// The text of the file at [path] as analyzed: its overlay, else the
  /// file on disk.
  String read(String path) => _provider.getFile(path).readAsStringSync();

  /// Analyzes [content] as the file at [path], once [applyChanges] runs.
  void overlay(String path, String content) {
    _provider.setOverlay(
      path,
      content: content,
      modificationStamp: _modificationStamp++,
    );
    collection.contextFor(path).changeFile(path);
  }

  /// Analyzes the file at [path] on disk again, once [applyChanges] runs.
  void removeOverlay(String path) {
    _provider.removeOverlay(path);
    collection.contextFor(path).changeFile(path);
  }

  /// Lets every context take in the files changed.
  Future<void> applyChanges() async {
    for (final context in collection.contexts) {
      await context.applyPendingFileChanges();
    }
  }

  /// Compile errors [path] has in the current analysis.
  Future<List<String>> errorsIn(String path) =>
      compileErrors(collection.contextFor(path).currentSession, path);

  /// How many compile errors each of [paths] has now.
  Future<Map<String, int>> errorCounts(Iterable<String> paths) async => {
    for (final path in paths) path: (await errorsIn(path)).length,
  };

  /// Throws what [failure] makes of a message saying [action] would break
  /// the build, quoting the first new error of each file, when any of
  /// [paths] has more compile errors than [before] counts (none when it
  /// doesn't count the file).
  Future<void> checkNoNewErrors(
    Iterable<String> paths,
    Map<String, int> before, {
    required String action,
    Object Function(String message) failure = StateError.new,
  }) async {
    final problems = <String>[];
    for (final path in paths) {
      final errors = await errorsIn(path);
      if (errors.length > (before[path] ?? 0)) problems.add(errors.first);
    }
    if (problems.isNotEmpty) {
      throw failure(
        '$action would break the build, so nothing was changed:\n'
        '${problems.join('\n')}',
      );
    }
  }
}
