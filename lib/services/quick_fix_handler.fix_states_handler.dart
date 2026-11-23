part of 'quick_fix_handler.dart';

/// Runs [QuickFix.fixStates]: finds the widget `State`s out of place with
/// [WidgetStateAnalyzer], then tidies each of their widgets' files with
/// the class splitter, its `State`s only, one file after the other. A
/// `State` in another library than its widget, or one that can't be moved
/// safely, is left as it is, the summary saying why.
class FixStatesHandler implements QuickFixHandler {
  /// Creates the handler finding the `State`s with [_analyzer], tidying
  /// them with [_splitter] and writing them with [_files].
  const FixStatesHandler(this._analyzer, this._splitter, this._files);

  final WidgetStateAnalyzer _analyzer;

  final FileContentReader _files;

  final ClassSplitService _splitter;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    final projectPath = request.projectPath;
    final analyzer = _analyzer;
    final findings = (await Isolate.run(() => analyzer.analyze(projectPath)))
        .findings;
    if (findings.isEmpty) return _nothingToDo('Every State is in place');
    final widgetFiles = {
      for (final finding in findings)
        if (finding.isInWidgetLibrary) finding.widgetPath,
    };
    final splits = _SplitRun(_splitter, _files);
    splits.skipped.addAll([
      for (final finding in findings)
        if (!finding.isInWidgetLibrary)
          '${p.basename(finding.path)}: ${finding.state} is in another '
              'library than ${finding.widget}; move it by hand',
    ]);
    if (widgetFiles.isNotEmpty &&
        !await request.confirm(
          'Fix the States of ${widgetFiles.length.count('widget file')}? '
          '${QuickFix.fixStates.purpose.capitalized}.',
        )) {
      return null;
    }
    await splits.run(projectPath, widgetFiles, statesOnly: true);
    return splits.outcome(
      splits.results.isEmpty
          ? 'Fixed no State'
          : splits.results.map((result) => result.summary).join('; '),
    );
  }
}
