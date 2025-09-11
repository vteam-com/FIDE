import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:fide/models/file_system_item.dart';

class FileSystemService {
  static final FileSystemService _instance = FileSystemService._internal();
  factory FileSystemService() => _instance;
  FileSystemService._internal();

  // Get the application documents directory
  Future<String> getDocumentsDirectory() async {
    // For now, we'll use the user's home directory
    // In a real app, you might want to use path_provider
    return Platform.isWindows
        ? 'C:\\Users\\${Platform.environment['USERNAME']}'
        : Platform.environment['HOME'] ?? '/';
  }

  // List contents of a directory
  Future<List<FileSystemItem>> listDirectory(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $dirPath');
    }

    final List<FileSystemItem> items = [];
    final List<FileSystemEntity> entities;

    try {
      entities = directory.listSync();
    } catch (e) {
      throw Exception('Error reading directory: $e');
    }

    // Add parent directory if not at root
    if (dirPath != '/' && !dirPath.endsWith(':/') && !dirPath.endsWith(':/')) {
      items.add(FileSystemItem.parentDirectory(dirPath));
    }

    // Sort directories first, then files, both alphabetically
    entities.sort((a, b) {
      final aIsDir = FileSystemEntity.isDirectorySync(a.path);
      final bIsDir = FileSystemEntity.isDirectorySync(b.path);
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return path.basename(a.path).toLowerCase().compareTo(
            path.basename(b.path).toLowerCase(),
          );
    });

    // Convert to FileSystemItem
    for (var entity in entities) {
      try {
        items.add(FileSystemItem.fromFileSystemEntity(entity));
      } catch (e) {
        // Skip files we can't access
        continue;
      }
    }

    return items;
  }

  // Create a new file
  Future<File> createFile(String filePath, {String content = ''}) async {
    final file = File(filePath);
    await file.writeAsString(content);
    return file;
  }

  // Create a new directory
  Future<Directory> createDirectory(String dirPath) async {
    final directory = Directory(dirPath);
    await directory.create(recursive: true);
    return directory;
  }

  // Delete a file or directory
  Future<void> delete(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (entity == FileSystemEntityType.file) {
      await File(path).delete();
    }
  }

  // Rename a file or directory
  Future<void> rename(String oldPath, String newPath) async {
    final entity = FileSystemEntity.typeSync(oldPath);
    if (entity == FileSystemEntityType.directory) {
      await Directory(oldPath).rename(newPath);
    } else if (entity == FileSystemEntityType.file) {
      await File(oldPath).rename(newPath);
    }
  }

  // Check if a path is a directory
  bool isDirectory(String path) {
    return FileSystemEntity.isDirectorySync(path);
  }

  // Get file size in human-readable format
  String getFileSize(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // Get file icon based on extension
  static String getFileIcon(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    
    // Directories
    if (fileName == '..') return 'assets/icons/folder-up.png';
    if (FileSystemEntity.isDirectorySync(fileName)) return 'assets/icons/folder.png';
    
    // File types
    switch (ext) {
      case '.dart':
        return 'assets/icons/file-dart.png';
      case '.yaml':
      case '.yml':
        return 'assets/icons/file-yaml.png';
      case '.json':
        return 'assets/icons/file-json.png';
      case '.md':
      case '.markdown':
        return 'assets/icons/file-markdown.png';
      case '.html':
      case '.htm':
        return 'assets/icons/file-html.png';
      case '.css':
        return 'assets/icons/file-css.png';
      case '.js':
      case '.jsx':
      case '.ts':
      case '.tsx':
        return 'assets/icons/file-js.png';
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
      case '.webp':
        return 'assets/icons/file-image.png';
      default:
        return 'assets/icons/file.png';
    }
  }
}

// Helper functions
double log(int x) => x <= 0 ? 0 : log(x) / ln10;

num pow(num x, num exponent) {
  if (exponent == 0) return 1;
  if (exponent == 1) return x;
  return x * pow(x, exponent - 1);
}

const double ln10 = 2.302585092994046;
