import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
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
