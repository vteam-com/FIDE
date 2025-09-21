import 'dart:io';

/// Utility functions for file operations
class FileUtils {
  static const int maxFileSize = 1 * 1024 * 1024; // 1MB
  static const String fileTooBigMessage = 'file too big to load';

  /// Read file content safely with size limit
  static Future<String> readFileContentSafely(File file) async {
    final fileSize = await file.length();
    if (fileSize > maxFileSize) {
      return fileTooBigMessage;
    }
    return await file.readAsString();
  }
}
