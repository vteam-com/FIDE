import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Reads, writes and compares ARB files: decoding and encoding their JSON,
/// loading a folder of them into [ArbFile] models and comparing the
/// languages' coverage of each key.
class ArbService {
  static final Logger _logger = Logger('ArbService');

  /// Creates an ARB service.
  const ArbService();

  /// Byte-order mark some editors put at the start of ARB files.
  static const String _byteOrderMark = '\uFEFF';

  /// Decodes ARB [content] (ignoring a leading byte-order mark), or null
  /// when it isn't a JSON object.
  static Map<String, dynamic>? decode(String content) {
    final clean = content.startsWith(_byteOrderMark)
        ? content.substring(_byteOrderMark.length)
        : content;
    try {
      final decoded = jsonDecode(clean);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// [json] as ARB file content, indented like the editor's Format.
  static String encode(Map<String, dynamic> json) =>
      '${const JsonEncoder.withIndent(CodeFormatter.jsonIndent).convert(json)}\n';

  /// Number of translatable entries (keys not starting with `@`) in ARB
  /// [content], or null when it isn't valid.
  static int? countEntries(String content) {
    return decode(content)?.keys.where((key) => !key.startsWith('@')).length;
  }

  /// English values shared by at least [AppMetric.duplicateThreshold] of
  /// [comparisons].
  static Set<String> duplicatedEnglishValues(
    Iterable<ArbComparison> comparisons,
  ) {
    final counts = <String, int>{};
    for (final comparison in comparisons) {
      final value = comparison.englishValue;
      if (value != null) counts[value] = (counts[value] ?? 0) + 1;
    }
    return {
      for (final entry in counts.entries)
        if (entry.value >= AppMetric.duplicateThreshold) entry.key,
    };
  }

  /// Loads every ARB file under [directoryPath], splitting the ones that
  /// parsed from the paths of the malformed ones.
  Future<({List<ArbFile> valid, List<String> malformed})> loadArbFiles(
    String directoryPath,
  ) async {
    final directory = Directory(directoryPath);
    final valid = <ArbFile>[];
    final malformed = <String>[];

    if (await directory.exists()) {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.arb')) {
          ArbFile? arbFile;
          try {
            arbFile = await parseArbFile(entity.path);
          } catch (e) {
            _logger.severe('Error parsing ARB file ${entity.path}: $e');
          }
          if (arbFile == null) {
            malformed.add(entity.path);
          } else {
            valid.add(arbFile);
          }
        }
      }
    }

    _logger.info(
      'ARB files: ${valid.length} valid, ${malformed.length} malformed',
    );
    return (valid: valid, malformed: malformed);
  }

  /// Parses one ARB file into an [ArbFile] model with entries and metadata;
  /// null when it isn't a JSON object.
  Future<ArbFile?> parseArbFile(String path) async {
    final content = await File(path).readAsString();
    final json = decode(content);
    if (json == null) {
      _logger.severe(
        'ARB file $path is not a JSON object. Raw content (first ${AppMetric.logPreviewChars} chars): ${content.truncated(AppMetric.logPreviewChars)}',
      );
      return null;
    }

    final entries = <String, ArbEntry>{};
    final metadata = <String, Map<String, dynamic>>{};

    for (final key in json.keys) {
      if (key.startsWith('@')) {
        final originalKey = key.substring(1);
        final meta = json[key];
        if (meta is Map<String, dynamic>) {
          metadata[originalKey] = meta;
        } else {
          _logger.warning(
            'Metadata for $originalKey is not a valid map, skipping',
          );
        }
      }
    }

    for (final key in json.keys) {
      if (!key.startsWith('@')) {
        final value = json[key];
        final entryMetadata = metadata[key];
        entries[key] = ArbEntry.fromJson(key, value, entryMetadata);
      }
    }

    final filename = p.basename(path);
    final languageCode = ArbFile.extractLanguageCode(filename);

    return ArbFile(path: path, languageCode: languageCode, entries: entries);
  }

  /// Compares ARB files and returns per-key coverage and missing-language data.
  List<ArbComparison> compareArbFiles(List<ArbFile> arbFiles) {
    final comparisons = <ArbComparison>[];

    if (arbFiles.isEmpty) {
      return comparisons;
    }

    final englishFile = arbFiles.firstWhere(
      (file) => file.languageCode.toLowerCase() == 'en',
      orElse: () => arbFiles.first,
    );

    final otherFiles = arbFiles.where((file) => file != englishFile).toList();

    final allKeys = <String>{};
    for (final file in arbFiles) {
      allKeys.addAll(file.entries.keys);
    }

    for (final key in allKeys) {
      final englishValue = englishFile.entries[key]?.value;
      final otherValues = <String, String?>{};

      for (final file in otherFiles) {
        otherValues[file.languageCode] = file.entries[key]?.value;
      }

      final missingInLanguages = otherFiles
          .where((file) => !file.entries.containsKey(key))
          .map((file) => file.languageCode)
          .toList();

      comparisons.add(
        ArbComparison(
          key: key,
          englishValue: englishValue,
          otherValues: otherValues,
          isMissingInEnglish: englishValue == null,
          missingInLanguages: missingInLanguages,
        ),
      );
    }

    return comparisons;
  }
}
