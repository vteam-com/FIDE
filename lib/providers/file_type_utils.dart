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

part 'file_type_utils.file_icon_utils.dart';

/// Represents `FileTypeUtils`.
class FileTypeUtils {
  // Well-known text file extensions that should open in text editor
  static const List<String> supportedTextExtensions = [
    // Programming languages
    'arb',
    'dart',
    'c',
    'cc',
    'cpp',
    'cxx',
    'h',
    'hpp',
    'rs',
    'go',
    'java',
    'kt',
    'scala',
    // xcode
    'swift',
    'm',
    'mm',
    // Web technologies
    'js',
    'ts',
    'jsx',
    'tsx',
    'vue',
    'svelte',
    'html',
    'xml',
    'svg',
    'css',
    'scss',
    'sass',
    'less',
    // Data formats
    'json', 'yaml', 'yml', 'toml', 'xml', 'csv', 'dot',
    // Documentation
    'md', 'txt', 'rst', 'adoc',
    // Configuration files
    'ini', 'cfg', 'conf', 'properties', 'env', 'lock', 'plist',
    // Scripts
    'sh', 'bash', 'zsh', 'fish', 'ps1', 'bat', 'cmd',
    // Python
    'py', 'pyw', 'pyx', 'pxd', 'pxi',
    // Other common text files
    'log', 'out', 'gitignore', 'dockerignore',
  ];

  // Image file extensions that should display as images
  static const List<String> supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
    'tiff',
    'tif',
  ];

  // Syntax highlighting language for each file extension shown in the editor
  static final Map<String, Mode> _languageByExtension = {
    'arb': langJson,
    'bash': langBash,
    'bat': langDos,
    'c': langC,
    'cc': langCpp,
    'cfg': langIni,
    'cmd': langDos,
    'conf': langIni,
    'cpp': langCpp,
    'css': langCss,
    'cxx': langCpp,
    'dart': langDart,
    'fish': langBash,
    'go': langGo,
    'h': langC,
    'hpp': langCpp,
    'html': langXml,
    'ini': langIni,
    'java': langJava,
    'js': langJavascript,
    'json': langJson,
    'jsx': langJavascript,
    'kt': langKotlin,
    'less': langLess,
    'm': langObjectivec,
    'md': langMarkdown,
    'mm': langObjectivec,
    'plist': langXml,
    'properties': langProperties,
    'ps1': langPowershell,
    'py': langPython,
    'pyw': langPython,
    'rs': langRust,
    'sass': langScss,
    'scala': langScala,
    'scss': langScss,
    'sh': langBash,
    'svg': langXml,
    'swift': langSwift,
    'toml': langIni,
    'ts': langTypescript,
    'tsx': langTypescript,
    'xml': langXml,
    'yaml': langYaml,
    'yml': langYaml,
    'zsh': langBash,
  };

  /// Check if a file is a supported source file that can be opened in the editor
  static bool isFileSupportedInEditor(String filePath) {
    if (filePath.isEmpty) {
      return false;
    }
    final extension = filePath.split('.').last.toLowerCase();

    return supportedTextExtensions.contains(extension) ||
        supportedImageExtensions.contains(extension);
  }

  /// Check if a file is a supported text file
  static bool isTextFile(String filePath) {
    if (filePath.isEmpty) return false;
    final extension = filePath.split('.').last.toLowerCase();

    return supportedTextExtensions.contains(extension);
  }

  /// Check if a file is a supported image file
  static bool isImageFile(String filePath) {
    if (filePath.isEmpty) return false;
    final extension = filePath.split('.').last.toLowerCase();

    return supportedImageExtensions.contains(extension);
  }

  /// Returns the syntax highlighting language for [filePath], or plain text
  /// when the extension has no known language.
  static Mode languageForFile(String filePath) {
    if (filePath.isEmpty) return langPlaintext;
    final extension = filePath.split('.').last.toLowerCase();

    return _languageByExtension[extension] ?? langPlaintext;
  }
}
