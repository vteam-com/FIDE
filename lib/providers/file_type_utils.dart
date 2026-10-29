// Utility functions for file type detection
// ignore: fcheck_dead_code

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/dos.dart';
import 'package:re_highlight/languages/go.dart';
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
part 'file_type_utils.file_icon_utils.dart';
part 'file_type_utils.file_type_info.dart';

/// Answers what FIDE knows about a file from its extension: whether the
/// editor opens it, how it is highlighted, and which icon it gets.
///
/// Everything comes from the one [_types] table, so supporting a new
/// extension is a single entry.
class FileTypeUtils {
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
    'svg': FileTypeInfo.text(FileCategory.image, langXml),
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
    'gradle': const FileTypeInfo.other(FileCategory.config),
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
    // Images shown in the image viewer
    'png': const FileTypeInfo.image(),
    'jpg': const FileTypeInfo.image(),
    'jpeg': const FileTypeInfo.image(),
    'gif': const FileTypeInfo.image(),
    'bmp': const FileTypeInfo.image(),
    'webp': const FileTypeInfo.image(),
    'tiff': const FileTypeInfo.image(),
    'tif': const FileTypeInfo.image(),
    // Recognized but not opened
    'ora': const FileTypeInfo.other(FileCategory.image),
    'pdf': const FileTypeInfo.other(FileCategory.pdf),
    'zip': const FileTypeInfo.other(FileCategory.archive),
    'rar': const FileTypeInfo.other(FileCategory.archive),
    '7z': const FileTypeInfo.other(FileCategory.archive),
    'tar': const FileTypeInfo.other(FileCategory.archive),
    'gz': const FileTypeInfo.other(FileCategory.archive),
  };

  /// Check if a file is a supported source file that can be opened in the editor
  static bool isFileSupportedInEditor(String filePath) {
    final type = _typeOf(filePath);
    return type != null && type.opensAs != FileOpening.none;
  }

  /// Check if a file is a supported image file
  static bool isImageFile(String filePath) {
    return _typeOf(filePath)?.opensAs == FileOpening.image;
  }

  /// Check if a file is a supported text file
  static bool isTextFile(String filePath) {
    return _typeOf(filePath)?.opensAs == FileOpening.text;
  }

  /// Returns the syntax highlighting language for [filePath], or plain text
  /// when the extension has no known language.
  static Mode languageForFile(String filePath) {
    return _typeOf(filePath)?.language ?? langPlaintext;
  }

  /// The icon category for files with [extension], case-insensitive.
  static FileCategory categoryOf(String extension) {
    return _types[extension.toLowerCase()]?.category ?? FileCategory.other;
  }

  /// The lowercase text after [filePath]'s last dot (the whole name when
  /// it has none, so `.gitignore` gives `gitignore`).
  static String extensionOf(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Name of [filePath]'s language for the status bar; `Text` for plain
  /// text and unknown types.
  static String languageLabel(String filePath) {
    final type = _typeOf(filePath);
    if (type == null || type.language == null) return 'Text';
    return type.label ?? extensionOf(filePath).toUpperCase();
  }

  /// The table entry for [filePath]'s extension, or null when unknown.
  static FileTypeInfo? _typeOf(String filePath) {
    if (filePath.isEmpty) return null;
    return _types[extensionOf(filePath)];
  }
}
