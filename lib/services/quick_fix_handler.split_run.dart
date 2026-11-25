part of 'quick_fix_handler.dart';

/// [ClassSplitService] runs on files one after the other, each planned on
/// the files written by the runs before it: writes each run's files and
/// deletes the part files it empties, reporting each file as a step; a
/// file that can't be changed safely is left as it is, [skipped] saying
/// why; Cancel stops them before the next file is written.
class _SplitRun {
  /// Creates the runs planning with [_splitter] and writing with [_files],
  /// for [_request], whose steps they report and whose cancel stops them.
  _SplitRun(this._splitter, this._files, this._request);

  final FileContentReader _files;

  final QuickFixRequest _request;

  final ClassSplitService _splitter;

  /// Whether the user stopped the runs, before the end.
  bool cancelled = false;

  /// Every file written or deleted, by absolute path.
  final Set<String> changed = {};

  /// What each run that changed its file did, in run order.
  final List<ClassSplitResult> results = [];

  /// Each file left as it is, by name, with why.
  final List<String> skipped = [];

  /// Runs the splitter on each of [paths], only on its widgets' `State`s
  /// when [statesOnly], reporting each as [verb] it, until the user
  /// cancels: a file planned meanwhile isn't written.
  Future<void> run(
    Iterable<String> paths, {
    required String verb,
    bool statesOnly = false,
  }) async {
    final all = paths.toList();
    for (final (index, path) in all.indexed) {
      if (_isCancelled) break;
      _request.onProgress?.call(
        '$verb ${p.basename(path)} (${(index + 1).localized} of '
        '${all.length.localized})…',
      );
      _request.onFileStart?.call(path);
      try {
        final result = await _splitter.plan(
          projectPath: _request.projectPath,
          filePath: path,
          statesOnly: statesOnly,
        );
        if (_isCancelled) break;
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
        _request.onFilesDone?.call({
          path,
          ...result.files.keys,
          ...result.mergedFiles.keys,
        }, succeeded: true);
      } on ClassSplitException catch (e) {
        skipped.add('${p.basename(path)}: ${e.message}');
        _request.onFilesDone?.call([path], succeeded: false);
      }
    }
  }

  /// Whether the user asked to stop, noting it in [cancelled].
  bool get _isCancelled =>
      cancelled = cancelled || (_request.cancel?.isCancelled ?? false);

  /// The outcome of the runs, [done] saying what they did, after
  /// `Cancelled` when the user stopped them, then the files left and why.
  QuickFixOutcome outcome(String done) => (
    summary: [
      if (cancelled) 'Cancelled',
      done,
      if (skipped.isNotEmpty) 'left ${skipped.join('; ')}',
    ].join('; '),
    changedFiles: changed.toList(),
  );
}
