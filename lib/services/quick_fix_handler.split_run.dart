part of 'quick_fix_handler.dart';

/// [ClassSplitService] runs on files one after the other, each planned on
/// the files written by the runs before it: writes each run's files and
/// deletes the part files it empties; a file that can't be changed safely
/// is left as it is, [skipped] saying why.
class _SplitRun {
  /// Creates the runs planning with [_splitter] and writing with [_files].
  _SplitRun(this._splitter, this._files);

  final FileContentReader _files;

  final ClassSplitService _splitter;

  /// Every file written or deleted, by absolute path.
  final Set<String> changed = {};

  /// What each run that changed its file did, in run order.
  final List<ClassSplitResult> results = [];

  /// Each file left as it is, by name, with why.
  final List<String> skipped = [];

  /// Runs the splitter on each of [paths] of the project at
  /// [projectPath], only on its widgets' `State`s when [statesOnly].
  Future<void> run(
    String projectPath,
    Iterable<String> paths, {
    bool statesOnly = false,
  }) async {
    for (final path in paths) {
      try {
        final result = await _splitter.plan(
          projectPath: projectPath,
          filePath: path,
          statesOnly: statesOnly,
        );
        for (final MapEntry(key: file, value: content)
            in result.files.entries) {
          await _files.write(file, content);
        }
        for (final merged in result.mergedFiles.keys) {
          await _files.delete(merged);
        }
        changed
          ..addAll(result.files.keys)
          ..addAll(result.mergedFiles.keys);
        results.add(result);
      } on ClassSplitException catch (e) {
        skipped.add('${p.basename(path)}: ${e.message}');
      }
    }
  }

  /// The outcome of the runs, [done] saying what they did, then the files
  /// left and why.
  QuickFixOutcome outcome(String done) => (
    summary: [
      done,
      if (skipped.isNotEmpty) 'left ${skipped.join('; ')}',
    ].join('; '),
    changedFiles: changed.toList(),
  );
}
