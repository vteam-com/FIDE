import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/hardcoded_string_finder.dart';
import 'package:fide/services/localization_service.dart';
import 'package:path/path.dart' as p;

/// Translates ARB keys with the local model in short batches, FIDE writing
/// the ARB files itself: the model only ever sees a list of texts to
/// translate and returns the list translated, never the files, so it stays
/// fast and cannot break them.
class ArbTranslator {
  /// Creates a translator asking [_model] and regenerating through
  /// [_localization].
  const ArbTranslator(this._model, this._localization);

  /// Reason for translations that lost a placeholder of the template.
  static const String lostPlaceholder = 'that lost a {placeholder}';

  /// Reason for keys the model gave no translation for.
  static const String noReply = 'with no reply from the model';

  /// Reason for keys whose text is the same in the other language, such as
  /// a name, which are marked [reviewedDescription].
  static const String sameText = 'the same in both languages, marked reviewed';

  /// `@key` description telling fCheck that a translation identical to the
  /// template is intended.
  static const String reviewedDescription = 'reviewed';

  /// Texts per model request.
  static const int _batchSize = AppMetric.aiTranslateBatch;

  /// Reasoning a thinking model may leave in its reply.
  static final RegExp _thinking = RegExp(r'<think>[\s\S]*?</think>');

  final ChatModel _model;

  final LocalizationService _localization;

  /// The keys fCheck found missing, empty, untranslated or with wrong
  /// placeholders in the project at [projectPath]'s other languages.
  Future<List<ArbTranslation>> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    final config = await _localization.l10nConfig(projectPath);
    final template = config.templateParts;
    final templateFile = File(
      p.join(projectPath, config.arbDir, config.templateArbFile),
    );
    if (template == null || !await templateFile.exists()) return [];
    final source =
        ArbService.decode(await templateFile.readAsString()) ?? const {};
    return [
      for (final issue in metrics.localizationIssues)
        if (issue.languageCode != template.locale)
          for (final detail in issue.details)
            if (QuickFix.translateKeys.localizationProblems.contains(
                  detail.problemType.name,
                ) &&
                source[detail.key] is String)
              ArbTranslation(
                key: detail.key,
                source: source[detail.key] as String,
                description: _description(source['@${detail.key}']),
                language: issue.languageName,
                arbPath: p.join(
                  projectPath,
                  config.arbDir,
                  '${template.prefix}${issue.languageCode}.arb',
                ),
              ),
    ];
  }

  /// The `description` of an ARB key's [metadata], or null when it has
  /// none.
  static String? _description(Object? metadata) {
    final description = metadata is Map ? metadata['description'] : null;
    return description is String && description.isNotEmpty ? description : null;
  }

  /// Asks the model for [translations] in batches per language, telling
  /// [onProgress] about each batch, writes the ones keeping every
  /// placeholder to their ARB files and regenerates the classes of the
  /// project at [projectPath]. A translation identical to the template is
  /// marked [reviewedDescription], so fCheck stops flagging it. When the
  /// model fails or [cancel] stops it, the translations so far are still
  /// saved before the error is thrown.
  Future<StringRewrite> apply(
    String projectPath,
    List<ArbTranslation> translations, {
    void Function(String)? onProgress,
    AiCancelToken? cancel,
  }) async {
    final byFile = <String, Map<String, String>>{};
    final reviewedByFile = <String, Set<String>>{};
    final skipped = <String, int>{};
    final byLanguage = <String, List<ArbTranslation>>{};
    for (final translation in translations) {
      (byLanguage[translation.language] ??= []).add(translation);
    }
    Object? failure;
    batches:
    for (final MapEntry(key: language, value: pending) in byLanguage.entries) {
      for (var start = 0; start < pending.length; start += _batchSize) {
        final batch = pending.sublist(
          start,
          math.min(start + _batchSize, pending.length),
        );
        onProgress?.call(
          'Translating ${start + 1}–${start + batch.length} of '
          '${pending.length} keys into $language…',
        );
        final List<String> texts;
        try {
          texts = await _translate(batch, language, cancel);
        } catch (e) {
          failure = e;
          break batches;
        }
        for (final (index, translation) in batch.indexed) {
          final text = texts[index];
          if (text.isEmpty || !translation.placeholders.every(text.contains)) {
            HardcodedStringFinder.count(
              skipped,
              text.isEmpty ? noReply : lostPlaceholder,
            );
            continue;
          }
          (byFile[translation.arbPath] ??= {})[translation.key] = text;
          if (text == translation.source) {
            HardcodedStringFinder.count(skipped, sameText);
            (reviewedByFile[translation.arbPath] ??= {}).add(translation.key);
          }
        }
      }
    }

    for (final MapEntry(key: path, value: entries) in byFile.entries) {
      final file = File(path);
      final arb = await file.exists()
          ? ArbService.decode(await file.readAsString()) ?? {}
          : <String, dynamic>{};
      arb.addAll(entries);
      for (final key in reviewedByFile[path] ?? const <String>{}) {
        final metadata = arb['@$key'];
        arb['@$key'] = {
          if (metadata is Map) ...metadata,
          'description': reviewedDescription,
        };
      }
      await file.writeAsString(ArbService.encode(arb));
    }
    final written = byFile.values.fold(0, (sum, keys) => sum + keys.length);
    if (written > 0) await _localization.generateClasses(projectPath);
    final reviewed = reviewedByFile.values.fold(
      0,
      (sum, keys) => sum + keys.length,
    );
    final result = StringRewrite(
      action: 'Translated',
      rewritten: written - reviewed,
      changedFiles: byFile.keys.toList(),
      skipped: skipped,
    );
    if (failure != null) {
      throw Exception('${result.summary}, then the model failed: $failure');
    }
    return result;
  }

  /// The sources of [texts], app interface texts in English, translated
  /// into [language] by the model in one request, keeping every
  /// `{placeholder}`; the same number of items, empty for each text
  /// without a usable reply.
  ///
  /// The model sees each text with its ARB key and description, which say
  /// where it appears, such as whether "Open" is a menu item or a state,
  /// but never the files, so a short list stays fast on a local model.
  /// Throws an [AiServiceException] when the request fails.
  Future<List<String>> _translate(
    List<ArbTranslation> texts,
    String language,
    AiCancelToken? cancel,
  ) async {
    final items = [
      for (final text in texts)
        {
          'key': text.key,
          'text': text.source,
          'description': ?text.description,
        },
    ];
    final response = await _model.generate(
      '''
Translate the "text" of each item of this JSON array of app interface texts from English to $language.
Each item's "key" and "description" tell where the text appears in the app: use them to pick the right meaning and wording, and do not translate them.
Keep every {placeholder} exactly as written. Reply with only a JSON array of the translated texts, as strings, in the same order and with the same number of items.

${jsonEncode(items)}''',
      AppDuration.aiGenerateTimeout,
      cancel: cancel,
    );
    final reply = response.replaceAll(_thinking, '');
    final start = reply.indexOf('[');
    final end = reply.lastIndexOf(']');
    final none = List.filled(texts.length, '');
    if (start < 0 || end < start) return none;
    try {
      final Object? decoded = jsonDecode(reply.substring(start, end + 1));
      if (decoded is! List || decoded.length != texts.length) return none;
      return [
        for (final item in decoded) item is String ? item.trim().unquoted : '',
      ];
    } on FormatException {
      return none;
    }
  }
}
