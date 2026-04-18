part of 'localization_service.dart';

/// Represents `ArbService`.
class ArbService {
  static final Logger _logger = Logger('ArbService');

  /// Loads and parses all ARB files found under the given directory tree.
  Future<List<ArbFile>> loadArbFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    final arbFiles = <ArbFile>[];

    if (!await directory.exists()) return arbFiles;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arb')) {
        _logger.info('Found ARB file: ${entity.path}');
        try {
          final arbFile = await parseArbFile(entity.path);
          if (arbFile != null) {
            arbFiles.add(arbFile);
          } else {
            _logger.warning('Failed to parse ARB file: ${entity.path}');
          }
        } catch (e) {
          _logger.severe('Error parsing ARB file ${entity.path}: $e');
        }
      }
    }

    _logger.info('Total ARB files found: ${arbFiles.length}');
    return arbFiles;
  }

  /// Parses one ARB file into an [ArbFile] model with entries and metadata.
  Future<ArbFile?> parseArbFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    final cleanContent = content.startsWith('\uFEFF')
        ? content.substring(1)
        : content;
    final decoded = jsonDecode(cleanContent);
    if (decoded is! Map<String, dynamic>) {
      _logger.severe(
        'ARB file $path does not contain a valid JSON object. Content length: ${content.length}, Clean content length: ${cleanContent.length}',
      );
      _logger.severe(
        'Raw content (first ${AppMetric.logPreviewChars} chars): ${content.substring(0, content.length > AppMetric.logPreviewChars ? AppMetric.logPreviewChars : content.length)}',
      );
      return null;
    }
    final json = decoded;

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

    final filename = path.split(Platform.pathSeparator).last;
    final languageCode = ArbFile.extractLanguageCode(filename);

    return ArbFile(path: path, languageCode: languageCode, entries: entries);
  }

  /// Returns true if the file contains a valid ARB-compatible JSON object.
  Future<bool> isArbFileValid(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final cleanContent = content.startsWith('\uFEFF')
          ? content.substring(1)
          : content;
      final decoded = jsonDecode(cleanContent);
      return decoded is Map<String, dynamic>;
    } catch (_) {
      return false;
    }
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

  /// Updates or inserts a key (and optional metadata) in an ARB file.
  Future<void> updateArbFile(
    String path,
    String key,
    String value, {
    Map<String, dynamic>? metadata,
  }) async {
    final file = File(path);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('ARB file $path does not contain a valid JSON object');
    }
    final json = decoded;

    json[key] = value;
    if (metadata != null) {
      json['@$key'] = metadata;
    }

    final updatedContent = jsonEncode(json);
    await file.writeAsString(updatedContent);
  }
}
