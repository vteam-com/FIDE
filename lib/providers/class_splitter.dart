import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:fide/models/class_split_result.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/providers/code_formatter.dart';
import 'package:fide/providers/compile_errors.dart';
import 'package:path/path.dart' as p;

part 'class_splitter.class_split_exception.dart';
part 'class_splitter.planner.dart';
part 'class_splitter.reference_collector.dart';

/// Deterministic "one public class per file" refactoring for Dart sources.
///
/// Every public class but one leaves the file for `<class_name>.dart` next
/// to it, importing only what it uses; the original file and every library
/// using the class through it get their imports updated. A class tangled
/// with the file's private declarations can't leave the library, so it
/// moves to a `part` file (`<file>.<class_name>.dart`) instead.
///
/// The analysis is resolved against the project's packages, and a plan that
/// would add compile errors is rejected.
class ClassSplitter {
  /// Creates a splitter resolving code against the Dart SDK at
  /// [dartSdkPath].
  const ClassSplitter({required this.dartSdkPath});

  /// Root of the Dart SDK (the folder holding `lib/core`).
  final String dartSdkPath;

  /// Writes [result]'s files, each formatted by [formatter] (as written when
  /// formatting fails).
  Future<void> apply(ClassSplitResult result, CodeFormatter formatter) async {
    for (final entry in result.files.entries) {
      String content;
      try {
        content = await formatter.format(entry.key, entry.value);
      } catch (_) {
        content = entry.value;
      }
      await File(entry.key).writeAsString(content);
    }
  }

  /// Plans the split of [filePath], analyzing [projectPath] in a background
  /// isolate; throws a [ClassSplitException] when it can't be done safely.
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
  }) {
    final sdkPath = dartSdkPath;
    return Isolate.run(
      () => _Planner(
        sdkPath: sdkPath,
        projectPath: projectPath,
        filePath: filePath,
      ).run(),
    );
  }
}
