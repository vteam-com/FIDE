// Utility functions for file type detection
// ignore: fcheck_dead_code
import 'package:fide/models/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
}
