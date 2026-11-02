part of 'quick_fix_handler.dart';

/// Runs [QuickFix.translateKeys] once the user confirms, the model
/// translating in short batches.
class TranslateKeysHandler implements QuickFixHandler {
  /// Creates the handler translating through [_translator].
  const TranslateKeysHandler(this._translator);

  final ArbTranslator _translator;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    final translations = await _translator.plan(
      request.projectPath,
      request.metrics,
    );
    if (translations.isEmpty) return _nothingToDo('Nothing to translate');
    final languages = {for (final t in translations) t.language};
    if (!await request.confirm(
      'The local model translates ${translations.length.localized} keys '
      'into ${languages.join(', ')} in short batches, keeping every '
      '{placeholder}; FIDE writes the ARB files and regenerates the '
      'classes.',
    )) {
      return null;
    }
    final result = await _translator.apply(
      request.projectPath,
      translations,
      onProgress: request.onProgress,
      cancel: request.cancel,
    );
    return (summary: result.summary, changedFiles: result.changedFiles);
  }
}
