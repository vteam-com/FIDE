import 'package:fide/models/class_split_result.dart';
import 'package:fide/services/class_splitter.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/flutter_sdk.dart';

/// Plans [ClassSplitter] splits against the Flutter SDK's Dart SDK, with
/// every resulting file formatted; writing them is left to the caller.
class ClassSplitService {
  /// Creates a service resolving the SDK through [_flutterSdk] and
  /// formatting with [_formatter].
  const ClassSplitService(this._flutterSdk, this._formatter);

  final FlutterSdk _flutterSdk;

  final CodeFormatter _formatter;

  /// Plans the split of [filePath] in the project at [projectPath]; throws
  /// a [ClassSplitException] when the SDK is missing or the split can't be
  /// done safely. A file the formatter rejects keeps its planned content.
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
  }) async {
    final sdkPath = await _flutterSdk.dartSdkPath();
    if (sdkPath == null) {
      throw const ClassSplitException('Flutter SDK not found');
    }
    final planned = await ClassSplitter(dartSdkPath: sdkPath)
        .plan(projectPath: projectPath, filePath: filePath);
    return ClassSplitResult(
      files: {
        for (final MapEntry(key: path, value: content) in planned.files.entries)
          path: await _formatted(path, content),
      },
      createdFiles: planned.createdFiles,
    );
  }

  /// [content] of [path] formatted, or as is when formatting fails.
  Future<String> _formatted(String path, String content) async {
    try {
      return await _formatter.format(path, content);
    } catch (_) {
      return content;
    }
  }
}
