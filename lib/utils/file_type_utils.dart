// Utility functions for file type detection

import 'package:fide/models/file_system_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

/// Shared utility for getting file icons
class FileIconUtils {
  static Widget getFileIcon(
    FileSystemItem item, {
    double size = 16,
    final Color? color,
  }) {
    switch (item.fileExtension.toLowerCase()) {
      case 'dart':
        return SvgPicture.asset(
          'assets/file_dart.svg',
          width: size,
          height: size,
        );
      // Programming languages
      case 'c':
      case 'cc':
      case 'cpp':
      case 'cxx':
      case 'h':
      case 'hpp':
      case 'rs':
      case 'go':
      case 'scala':
      case 'swift':
      case 'm':
      case 'mm':
      case 'py':
      case 'pyw':
      case 'pyx':
      case 'pxd':
      case 'pxi':
      case 'java':
      case 'kt':
        return Icon(Icons.developer_mode, size: size);
      // Web technologies
      case 'js':
        return Icon(Icons.javascript, size: size);
      case 'ts':
      case 'jsx':
      case 'tsx':
      case 'vue':
      case 'svelte':
      case 'html':
      case 'xml':
        return Icon(Icons.code, size: size);
      // Stylesheets
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return Icon(Icons.css, size: size);
      // Data formats
      case 'json':
      case 'arb':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'csv':
      case 'dot':
        return Icon(Icons.data_object, size: size);
      // Documentation
      case 'md':
      case 'markdown':
      case 'rst':
      case 'adoc':
        return Icon(Icons.text_snippet, size: size);
      // Configuration files
      case 'ini':
      case 'cfg':
      case 'conf':
      case 'properties':
      case 'env':
      case 'plist':
      case 'gradle':
        return Icon(Icons.build, size: size);
      // Lock files (JSON-based lock files)
      case 'lock':
        return Icon(Icons.lock, size: size);
      // Scripts
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
      case 'ps1':
      case 'bat':
      case 'cmd':
        return Icon(Icons.terminal, size: size);
      // Other text files
      case 'txt':
      case 'log':
      case 'out':
      case 'gitignore':
      case 'dockerignore':
        return Icon(Icons.article, size: size);
      // Images
      case 'gif':
      case 'jpeg':
      case 'jpg':
      case 'ora':
      case 'png':
      case 'svg':
      case 'webp':
      case 'bmp':
      case 'tiff':
      case 'tif':
        return Icon(Icons.image, size: size);
      // Documents
      case 'pdf':
        return Icon(Icons.picture_as_pdf, size: size);
      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icon(Icons.archive, size: size);
      default:
        return Icon(Icons.insert_drive_file, size: size);
    }
  }
}
