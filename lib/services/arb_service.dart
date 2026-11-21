import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/arb_message.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Reads, writes and compares ARB files: decoding and encoding their JSON,
/// loading a folder of them into [ArbFile] models and comparing the
/// languages' coverage of each key.
class ArbService {
  static final Logger _logger = Logger('ArbService');

  /// Creates an ARB service finding a project's ARB files with [_config].
  const ArbService([this._config = const ProjectConfigReader()]);

  /// ARB key naming the file's locale.
  static const String localeKey = '@@locale';

  /// Extension of ARB files.
  static const String arbExtension = '.arb';

  /// Byte-order mark some editors put at the start of ARB files.
  static const String _byteOrderMark = '\uFEFF';

  /// ARB files longer than this many characters are decoded on a
  /// background isolate by [parseArbFile].
  static const int _isolateDecodeChars = 64 * 1024;

  final ProjectConfigReader _config;

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
      CodeFormatter.encodeJson(json);

  /// The ARB file at [path], decoded; null when it does not exist or is
  /// not a JSON object.
  static Future<Map<String, dynamic>?> read(String path) async {
    final content = await ProjectConfigReader.readIfExists(path);
    return content == null ? null : decode(content);
  }

  /// Writes [arb] as the ARB file at [path].
  static Future<void> write(String path, Map<String, dynamic> arb) =>
      File(path).writeAsString(encode(arb));

  /// Reads the ARB file at [path], or starts from [orElse] (nothing by
  /// default) when it does not exist or is not valid, makes [change] to
  /// it and writes it back.
  static Future<void> update(
    String path,
    void Function(Map<String, dynamic> arb) change, {
    Map<String, dynamic> Function()? orElse,
  }) async {
    final arb = await read(path) ?? orElse?.call() ?? <String, dynamic>{};
    change(arb);
    await write(path, arb);
  }

  /// Paths of the ARB files directly in [directory]; none when it does
  /// not exist.
  static Future<List<String>> arbFilesIn(String directory) =>
      ProjectFiles.filesIn(directory, extension: arbExtension);

  /// Number of translatable entries (keys not starting with `@`) in ARB
  /// [content], or null when it isn't valid.
  static int? countEntries(String content) {
    return decode(content)?.keys.where(ArbKeys.isMessageKey).length;
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
      await for (final file in ProjectFiles.walk(
        directoryPath,
        extension: arbExtension,
      )) {
        ArbFile? arbFile;
        try {
          arbFile = await parseArbFile(file.path);
        } catch (e) {
          _logger.severe('Error parsing ARB file ${file.path}: $e');
        }
        if (arbFile == null) {
          malformed.add(file.path);
        } else {
          valid.add(arbFile);
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
    // Large files are decoded off the UI thread, small ones not worth
    // starting an isolate for
    final json = content.length > _isolateDecodeChars
        ? await Isolate.run(() => decode(content))
        : decode(content);
    if (json == null) {
      _logger.severe(
        'ARB file $path is not a JSON object. Raw content (first ${AppMetric.logPreviewChars} chars): ${content.truncated(AppMetric.logPreviewChars)}',
      );
      return null;
    }

    final entries = <String, ArbEntry>{};
    final metadata = <String, Map<String, dynamic>>{};

    for (final key in json.keys) {
      if (!ArbKeys.isMessageKey(key)) {
        final originalKey = key.substring(ArbKeys.metadataPrefix.length);
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
      if (ArbKeys.isMessageKey(key)) {
        final value = json[key];
        final entryMetadata = metadata[key];
        entries[key] = ArbEntry.fromJson(key, value, entryMetadata);
      }
    }

    final languageCode =
        L10nConfig.localeOf(p.basename(path)) ?? ArbFile.unknownLanguageCode;

    return ArbFile(path: path, languageCode: languageCode, entries: entries);
  }

  /// Compares [arbFiles] against the one of [templateLocale] (the first
  /// when none is, or when it is null), returning each key's values and
  /// the languages missing it.
  List<ArbComparison> compareArbFiles(
    List<ArbFile> arbFiles,
    String? templateLocale,
  ) {
    final template = templateOf(arbFiles, templateLocale);
    if (template == null) return [];
    final otherFiles = arbFiles.where((file) => file != template).toList();
    final allKeys = {for (final file in arbFiles) ...file.entries.keys};

    return [
      for (final key in allKeys)
        ArbComparison(
          key: key,
          englishValue: template.entries[key]?.value,
          otherValues: {
            for (final file in otherFiles)
              file.languageCode: file.entries[key]?.value,
          },
          description: ArbMessage.descriptionOf(
            template.entries[key]?.metadata,
          ),
        ),
    ];
  }

  /// The one of [arbFiles] the others are compared against: the file of
  /// [templateLocale], else the first; null when there is none.
  static ArbFile? templateOf(List<ArbFile> arbFiles, String? templateLocale) =>
      arbFiles
          .where((file) => file.languageCode == templateLocale)
          .firstOrNull ??
      arbFiles.firstOrNull;

  /// The ARB files of the project at [projectPath], from the folder its
  /// `l10n.yaml` names, split like [loadArbFiles] and compared against its
  /// template locale like [compareArbFiles], with the locale of the file
  /// they are compared against ([templateOf]); null without valid files.
  Future<
    ({
      List<ArbFile> valid,
      List<String> malformed,
      List<ArbComparison> comparisons,
      String? templateLocale,
    })
  >
  loadProject(String projectPath) async {
    final config = await _config.l10nConfig(projectPath);
    final files = await loadArbFiles(config.arbDirIn(projectPath));
    final templateLocale = config.templateParts?.locale;
    return (
      valid: files.valid,
      malformed: files.malformed,
      comparisons: compareArbFiles(files.valid, templateLocale),
      templateLocale: templateOf(files.valid, templateLocale)?.languageCode,
    );
  }
}
