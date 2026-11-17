import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:fide/models/class_split_result.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/services/compile_errors.dart';
import 'package:fide/services/dart_references.dart';
import 'package:path/path.dart' as p;

part 'class_splitter.class_split_exception.dart';
part 'class_splitter.planner.dart';

/// Deterministic "one public class per file" refactoring for Dart sources.
///
/// Every public class but one leaves the file for `<class_name>.dart` next
/// to it, importing only what it uses; the original file and every library
/// using the class through it get their imports updated. Private
/// declarations only that class uses go with it. A class tangled with
/// private declarations the rest of the library also uses can't leave the
/// library, so it moves to a `part` file (`<file>.<class_name>.dart`)
/// instead.
///
/// The analysis is resolved against the project's packages, and a plan that
/// would add compile errors is rejected.
class ClassSplitter {
  /// Creates a splitter resolving code against the Dart SDK at
  /// [dartSdkPath], reading the project's files through [readFile].
  const ClassSplitter({
    required this.dartSdkPath,
    this.readFile = _readFromDisk,
  });

  /// Root of the Dart SDK (the folder holding `lib/core`).
  final String dartSdkPath;

  /// Reads the text of the file at a path, by default from disk; the plan
  /// reads each file at most once. Runs in the background isolate.
  final String Function(String path) readFile;

  /// Plans the split of [filePath], analyzing [projectPath] in a background
  /// isolate; throws a [ClassSplitException] when it can't be done safely.
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
  }) {
    final sdkPath = dartSdkPath;
    final read = readFile;
    return Isolate.run(
      () => _Planner(
        sdkPath: sdkPath,
        projectPath: projectPath,
        filePath: filePath,
        readFile: read,
      ).run(),
    );
  }

  /// [path]'s text, read from disk.
  static String _readFromDisk(String path) => File(path).readAsStringSync();
}
