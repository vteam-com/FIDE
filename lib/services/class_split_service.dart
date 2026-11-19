import 'package:fide/models/class_split_result.dart';
import 'package:fide/services/class_splitter.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/flutter_sdk.dart';

/// Plans [ClassSplitter] splits against the Flutter SDK's Dart SDK, with
/// every resulting file formatted; writing them is left to the caller.
class ClassSplitService {
  /// Creates a service finding the Dart SDK with [_dartSdkPath], such as
  /// the session's `dartSdkPathProvider`, and formatting with [_formatter].
  const ClassSplitService(this._dartSdkPath, this._formatter);

  /// Root of the Dart SDK bundled with Flutter.
  final DartSdkFinder _dartSdkPath;

  final CodeFormatter _formatter;

  /// Plans the split of [filePath] in the project at [projectPath]; throws
  /// a [FlutterSdkNotFoundException] when the SDK is missing and a
  /// [ClassSplitException] when the split can't be done safely. A file the formatter rejects keeps its planned content.
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
  }) async {
    final planned = await ClassSplitter(dartSdkPath: await _dartSdkPath())
        .plan(projectPath: projectPath, filePath: filePath);
    return ClassSplitResult(
      files: await _formatter.formatAllOrKeep(planned.files),
      createdFiles: planned.createdFiles,
    );
  }
}
