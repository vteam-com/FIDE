import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/arb_message.dart';
import 'package:fide/models/arb_translation.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/model_reply.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/hardcoded_string_finder.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/project_config_reader.dart';

/// Translates ARB keys with the local model in short batches, FIDE writing
/// the ARB files itself: the model only ever sees a list of texts to
/// translate and returns the list translated, never the files, so it stays
/// fast and cannot break them.
class ArbTranslator {
  /// Creates a translator asking [_model], reading project settings with
  /// [_config] and regenerating through [_generator].
  const ArbTranslator(this._model, this._config, this._generator);

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

  /// Field of a request item naming its ARB key.
  static const String _keyField = 'key';

  /// Field of a request item holding the text to translate.
  static const String _textField = 'text';

  /// Field of a request item saying where the text appears.
  static const String _descriptionField = 'description';

  /// Reasoning a thinking model may leave in its reply.
  static final RegExp _thinking = RegExp(r'<think>[\s\S]*?</think>');

  final ChatModel _model;

  final ProjectConfigReader _config;

  final L10nGenerator _generator;

  /// The keys fCheck found missing, empty, untranslated or with wrong
  /// placeholders in the project at [projectPath]'s other languages.
  Future<List<ArbTranslation>> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    final config = await _config.l10nConfig(projectPath);
    final template = config.templateParts;
    final templatePath = config.templatePathIn(projectPath);
    if (template == null || !await File(templatePath).exists()) return [];
    final source = await ArbService.read(templatePath) ?? const {};
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
                description: descriptionOf(
                  source[ArbKeys.metadataKeyOf(detail.key)],
                ),
                language: issue.languageName,
                arbPath: config.arbPathFor(projectPath, issue.languageCode),
              ),
    ];
  }

  /// What translating [translations] does, as the user is asked to
  /// confirm it.
  static String describe(List<ArbTranslation> translations) {
    final languages = {for (final t in translations) t.language};
    return 'The local model translates ${translations.length.count('key')} '
        'into ${languages.join(', ')} in short batches, keeping every '
        '{placeholder}; FIDE writes the ARB files and regenerates the '
        'classes.';
  }

  /// The `description` of an ARB key's [metadata], or null when it has
  /// none.
  static String? descriptionOf(Object? metadata) {
    final description = metadata is Map
        ? metadata[ArbMessage.descriptionKey]
        : null;
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
          '${pending.length.count('key')} into $language…',
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
      await ArbService.update(path, (arb) {
        arb.addAll(entries);
        for (final key in reviewedByFile[path] ?? const <String>{}) {
          final metadataKey = ArbKeys.metadataKeyOf(key);
          final metadata = arb[metadataKey];
          arb[metadataKey] = {
            if (metadata is Map) ...metadata,
            ArbMessage.descriptionKey: reviewedDescription,
          };
        }
      });
    }
    final written = byFile.values.fold(0, (sum, keys) => sum + keys.length);
    if (written > 0) await _generator.generateClasses(projectPath);
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
          _keyField: text.key,
          _textField: text.source,
          _descriptionField: ?text.description,
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
      if (decoded is! List) return none;
      return [
        for (final text in _repliedTexts(decoded, texts) ?? none)
          text.trim().unquoted,
      ];
    } on FormatException {
      return none;
    }
  }

  /// The translation of each of [texts] in the model's reply [items]: the
  /// strings asked for, in order, or, as a model may answer in the shape
  /// of the request, items whose [_textField] is translated, matched by
  /// their [_keyField] when they have one; empty for a text without one.
  /// Null when [items] matches neither shape.
  static List<String>? _repliedTexts(
    List<Object?> items,
    List<ArbTranslation> texts,
  ) {
    final byKey = {
      for (final item in items)
        if (item case {
          _keyField: final String key,
          _textField: final String text,
        })
          key: text,
    };
    if (byKey.isNotEmpty) {
      return [for (final text in texts) byKey[text.key] ?? ''];
    }
    if (items.length != texts.length) return null;
    return [
      for (final item in items)
        switch (item) {
          final String text => text,
          {_textField: final String text} => text,
          _ => '',
        },
    ];
  }
}
