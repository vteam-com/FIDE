// Utility functions for file type detection
// ignore: fcheck_dead_code

import 'package:fide/models/asset_kind.dart';
import 'package:fide/models/file_extension.dart';
import 'package:path/path.dart' as p;
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/dos.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/less.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/objectivec.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/properties.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

part 'file_type_utils.file_category.dart';
part 'file_type_utils.file_type_info.dart';
part 'file_type_utils.file_view_kind.dart';

/// Answers what FIDE knows about a file from its name or extension: whether the
/// editor opens it, how it is highlighted, and which icon it gets.
///
/// Everything comes from the [_types] table, or [_namedTypes] for files
/// known by their whole name, so supporting a new type is a single entry.
class FileTypeUtils {
  /// The extension of Dart source files, as [extensionOf] gives it.
  static const String _dartExtension = 'dart';

  /// The extension of vector images, as [extensionOf] gives it.
  static const String _svgExtension = 'svg';

  /// Image extensions the image viewer can't decode: HEIC needs a codec
  /// neither Flutter on the desktop nor the `image` package has.
  static const Set<String> _undecodedImages = {'heic'};

  /// Font extensions the font viewer can't load: compressed web fonts.
  static const Set<String> _unloadedFonts = {'woff', 'woff2'};

  /// Files typed by their whole name rather than their extension, such as
  /// extensionless scripts.
  static final Map<String, FileTypeInfo> _namedTypes = {
    'gradlew': FileTypeInfo.text(FileCategory.script, langBash, 'Shell'),
  };

  static final Map<String, FileTypeInfo> _types = {
    // Dart and Flutter
    'dart': FileTypeInfo.text(FileCategory.dart, langDart, 'Dart'),
    'arb': FileTypeInfo.text(FileCategory.data, langJson),
    // Compiled languages
    'c': FileTypeInfo.text(FileCategory.source, langC),
    'cc': FileTypeInfo.text(FileCategory.source, langCpp),
    'cpp': FileTypeInfo.text(FileCategory.source, langCpp),
    'cxx': FileTypeInfo.text(FileCategory.source, langCpp),
    'h': FileTypeInfo.text(FileCategory.source, langC),
    'hpp': FileTypeInfo.text(FileCategory.source, langCpp),
    'rs': FileTypeInfo.text(FileCategory.source, langRust),
    'go': FileTypeInfo.text(FileCategory.source, langGo),
    'java': FileTypeInfo.text(FileCategory.source, langJava),
    'kt': FileTypeInfo.text(FileCategory.source, langKotlin),
    'scala': FileTypeInfo.text(FileCategory.source, langScala),
    'swift': FileTypeInfo.text(FileCategory.source, langSwift),
    'm': FileTypeInfo.text(FileCategory.source, langObjectivec),
    'mm': FileTypeInfo.text(FileCategory.source, langObjectivec),
    // Python
    'py': FileTypeInfo.text(FileCategory.source, langPython),
    'pyw': FileTypeInfo.text(FileCategory.source, langPython),
    'pyx': const FileTypeInfo.text(FileCategory.source),
    'pxd': const FileTypeInfo.text(FileCategory.source),
    'pxi': const FileTypeInfo.text(FileCategory.source),
    // Web
    'js': FileTypeInfo.text(FileCategory.javascript, langJavascript),
    'ts': FileTypeInfo.text(FileCategory.markup, langTypescript),
    'jsx': FileTypeInfo.text(FileCategory.markup, langJavascript),
    'tsx': FileTypeInfo.text(FileCategory.markup, langTypescript),
    'vue': const FileTypeInfo.text(FileCategory.markup),
    'svelte': const FileTypeInfo.text(FileCategory.markup),
    'html': FileTypeInfo.text(FileCategory.markup, langXml),
    'xml': FileTypeInfo.text(FileCategory.markup, langXml),
    'css': FileTypeInfo.text(FileCategory.stylesheet, langCss),
    'scss': FileTypeInfo.text(FileCategory.stylesheet, langScss),
    'sass': FileTypeInfo.text(FileCategory.stylesheet, langScss),
    'less': FileTypeInfo.text(FileCategory.stylesheet, langLess),
    // Data formats
    'json': FileTypeInfo.text(FileCategory.data, langJson),
    'yaml': FileTypeInfo.text(FileCategory.data, langYaml),
    'yml': FileTypeInfo.text(FileCategory.data, langYaml, 'YAML'),
    'toml': FileTypeInfo.text(FileCategory.data, langIni),
    'csv': const FileTypeInfo.text(FileCategory.data),
    'dot': const FileTypeInfo.text(FileCategory.data),
    // Documentation
    'md': FileTypeInfo.text(FileCategory.document, langMarkdown),
    'markdown': const FileTypeInfo.other(FileCategory.document),
    'rst': const FileTypeInfo.text(FileCategory.document),
    'adoc': const FileTypeInfo.text(FileCategory.document),
    'txt': const FileTypeInfo.text(FileCategory.text),
    // Configuration
    'ini': FileTypeInfo.text(FileCategory.config, langIni),
    'cfg': FileTypeInfo.text(FileCategory.config, langIni),
    'conf': FileTypeInfo.text(FileCategory.config, langIni),
    'properties': FileTypeInfo.text(FileCategory.config, langProperties),
    'env': const FileTypeInfo.text(FileCategory.config),
    'plist': FileTypeInfo.text(FileCategory.config, langXml),
    'gradle': FileTypeInfo.text(FileCategory.config, langGradle, 'Gradle'),
    'kts': FileTypeInfo.text(FileCategory.config, langKotlin, 'Kotlin'),
    'lock': const FileTypeInfo.text(FileCategory.lock),
    // Scripts
    'sh': FileTypeInfo.text(FileCategory.script, langBash),
    'bash': FileTypeInfo.text(FileCategory.script, langBash),
    'zsh': FileTypeInfo.text(FileCategory.script, langBash),
    'fish': FileTypeInfo.text(FileCategory.script, langBash),
    'ps1': FileTypeInfo.text(FileCategory.script, langPowershell),
    'bat': FileTypeInfo.text(FileCategory.script, langDos),
    'cmd': FileTypeInfo.text(FileCategory.script, langDos),
    // Other text
    'log': const FileTypeInfo.text(FileCategory.text),
    'out': const FileTypeInfo.text(FileCategory.text),
    'gitignore': const FileTypeInfo.text(FileCategory.text),
    'dockerignore': const FileTypeInfo.text(FileCategory.text),
    // Images shown in the image viewer, except the ones it can't decode
    for (final extension in AssetKind.images.extensions)
      extension: _undecodedImages.contains(extension)
          ? const FileTypeInfo.other(FileCategory.image)
          : const FileTypeInfo.image(),
    // Sounds shown in the audio editor
    for (final extension in AssetKind.audio.extensions)
      extension: const FileTypeInfo.audio(),
    // Fonts shown in the font viewer, except the ones it can't load
    for (final extension in AssetKind.fonts.extensions)
      extension: _unloadedFonts.contains(extension)
          ? const FileTypeInfo.other(FileCategory.font)
          : const FileTypeInfo.font(),
    // Recognized but not opened
    'ora': const FileTypeInfo.other(FileCategory.image),
    'pdf': const FileTypeInfo.other(FileCategory.pdf),
    'zip': const FileTypeInfo.other(FileCategory.archive),
    'rar': const FileTypeInfo.other(FileCategory.archive),
    '7z': const FileTypeInfo.other(FileCategory.archive),
    'tar': const FileTypeInfo.other(FileCategory.archive),
    'gz': const FileTypeInfo.other(FileCategory.archive),
  };

  /// How the editor shows [filePath]: as code, an image, a sound, a font,
  /// or not at all when its type is unknown or only recognized.
  static FileViewKind viewKindOf(String filePath) {
    return _typeOf(filePath)?.opensAs ?? FileViewKind.unsupported;
  }

  /// Check if a file is a supported source file that can be opened in the editor
  static bool isFileSupportedInEditor(String filePath) {
    return viewKindOf(filePath) != FileViewKind.unsupported;
  }

  /// Whether [filePath] is Dart source, by its extension.
  static bool isDartFile(String filePath) =>
      extensionOf(filePath) == _dartExtension;

  /// Whether [filePath] is an SVG vector image, by its extension.
  static bool isSvg(String filePath) => extensionOf(filePath) == _svgExtension;

  /// Check if a file is a supported image file
  static bool isImageFile(String filePath) {
    return viewKindOf(filePath) == FileViewKind.image;
  }

  /// Check if a file is a supported text file
  static bool isTextFile(String filePath) {
    return viewKindOf(filePath) == FileViewKind.code;
  }

  /// Returns the syntax highlighting language for [filePath], or plain text
  /// when the extension has no known language.
  static Mode languageForFile(String filePath) {
    return _typeOf(filePath)?.language ?? langPlaintext;
  }

  /// The icon category of [filePath], from its name or its extension.
  static FileCategory categoryOf(String filePath) {
    return _typeOf(filePath)?.category ?? FileCategory.other;
  }

  /// The lowercase extension of [filePath]'s file name, without its dot,
  /// as [fileExtensionOf] reads it: `.gitignore` gives `gitignore`.
  static String extensionOf(String filePath) => fileExtensionOf(filePath);

  /// Name of [filePath]'s language for the status bar; `Text` for plain
  /// text and unknown types.
  static String languageLabel(String filePath) {
    final type = _typeOf(filePath);
    if (type == null || type.language == null) return 'Text';
    return type.label ?? extensionOf(filePath).toUpperCase();
  }

  /// The table entry for [filePath]'s name, else its extension; null
  /// when unknown.
  static FileTypeInfo? _typeOf(String filePath) {
    if (filePath.isEmpty) return null;
    return _namedTypes[p.basename(filePath)] ?? _types[extensionOf(filePath)];
  }
}
