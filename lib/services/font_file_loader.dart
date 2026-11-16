import 'dart:io';

import 'package:flutter/services.dart';

/// Registers font files with the engine so text can be drawn in them,
/// each version of a file once, under a family name of its own.
class FontFileLoader {
  /// Bytes of a font file's signature, at its start.
  static const int _signatureLength = 4;

  /// Signatures of the font files the engine draws: TrueType (two forms),
  /// OpenType with PostScript outlines, and TrueType collections.
  static const List<List<int>> _signatures = [
    [0x00, 0x01, 0x00, 0x00],
    [0x74, 0x72, 0x75, 0x65], // 'true'
    [0x4F, 0x54, 0x54, 0x4F], // 'OTTO'
    [0x74, 0x74, 0x63, 0x66], // 'ttcf'
  ];

  /// Families registered or registering, by family name.
  static final Map<String, Future<String>> _families = {};

  const FontFileLoader._();

  /// Whether [bytes] start like a TrueType or OpenType font file.
  static bool isFontData(Uint8List bytes) {
    if (bytes.length < _signatureLength) return false;
    return _signatures.any(
      (signature) =>
          Iterable<int>.generate(_signatureLength)
              .every((index) => bytes[index] == signature[index]),
    );
  }

  /// Registers the font file at [filePath] and returns the family to draw
  /// text in it; a file changed on disk since is registered anew.
  ///
  /// Throws a [FormatException] when the file isn't a TrueType or OpenType
  /// font, and a [FileSystemException] when it can't be read.
  static Future<String> load(String filePath) async {
    final file = File(filePath);
    final modified = await file.lastModified();
    final family = 'fide-font:$filePath@${modified.microsecondsSinceEpoch}';
    final loading = _families.putIfAbsent(
      family,
      () => _register(file, family),
    );
    try {
      return await loading;
    } catch (_) {
      // Try again next time, once the file may be fixed
      _families.remove(family);
      rethrow;
    }
  }

  /// Reads [file] and registers it as [family].
  static Future<String> _register(File file, String family) async {
    final bytes = await file.readAsBytes();
    if (!isFontData(bytes)) {
      throw const FormatException('Not a TrueType or OpenType font');
    }
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    return family;
  }
}
