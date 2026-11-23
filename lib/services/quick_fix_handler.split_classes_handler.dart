part of 'quick_fix_handler.dart';

/// Runs [QuickFix.splitClasses] on each file breaking fCheck's one class
/// per file rule, one after the other, each planned on the files written
/// by the splits before it; a file that can't be split safely is left as
/// it is, the summary saying why.
class SplitClassesHandler implements QuickFixHandler {
  /// Creates the handler planning each split with [_splitter] and writing
  /// it with [_files].
  const SplitClassesHandler(this._splitter, this._files);

  final FileContentReader _files;

  final ClassSplitService _splitter;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    final metrics = request.metrics;
    final paths = [
      for (final file in metrics.fileMetrics)
        if (!file.isOneClassPerFileCompliant) metrics.absolutePathOf(file.path),
    ];
    if (paths.isEmpty) return _nothingToDo('Every file has one public class');
    if (!await request.confirm(
      'Split ${paths.length.count('file')} declaring more than one public '
      'class? ${QuickFix.splitClasses.purpose.capitalized}.',
    )) {
      return null;
    }
    final splits = _SplitRun(_splitter, _files, request);
    await splits.run(paths, verb: 'Splitting');
    return splits.outcome('Split ${splits.results.length.count('file')}');
  }
}
