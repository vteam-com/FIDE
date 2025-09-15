// Utility functions for file type detection

class FileTypeUtils {
  // Well-known text file extensions that should open in text editor
  static const List<String> supportedTextExtensions = [
    // Programming languages
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
    'swift',
    'm', // Objective-C
    'mm', // Objective-C++
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
  static bool isSourceFile(String filePath) {
    if (filePath.isEmpty) return false;
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
