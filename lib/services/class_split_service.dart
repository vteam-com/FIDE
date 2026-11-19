import 'package:fide/models/class_split_result.dart';
import 'package:fide/services/class_splitter.dart';
import 'package:fide/services/code_formatter.dart';

/// Plans [ClassSplitter] splits against the Flutter SDK's Dart SDK, with
/// every resulting file formatted; writing them is left to the caller.
class ClassSplitService {
  /// Creates a service finding the Dart SDK with [_dartSdkPath], such as
  /// the session's `dartSdkPathProvider`, and formatting with [_formatter].
  const ClassSplitService(this._dartSdkPath, this._formatter);

  /// Root of the Dart SDK bundled with Flutter; null when Flutter isn't
  /// found.
  final Future<String?> Function() _dartSdkPath;

  final CodeFormatter _formatter;

  /// Plans the split of [filePath] in the project at [projectPath]; throws
  /// a [ClassSplitException] when the SDK is missing or the split can't be
  /// done safely. A file the formatter rejects keeps its planned content.
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
  }) async {
    final sdkPath = await _dartSdkPath();
    if (sdkPath == null) {
      throw const ClassSplitException('Flutter SDK not found');
    }
    final planned = await ClassSplitter(dartSdkPath: sdkPath)
        .plan(projectPath: projectPath, filePath: filePath);
    return ClassSplitResult(
      files: await _formatter.formatAllOrKeep(planned.files),
      createdFiles: planned.createdFiles,
    );
  }
}
