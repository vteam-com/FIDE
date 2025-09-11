import 'dart:io';
import 'package:path/path.dart' as p;

enum FileSystemItemType { file, directory, drive, parent }

class FileSystemItem {
  final String name;
  final String path;
  final FileSystemItemType type;
  final DateTime? modified;
  final int? size;
  final List<FileSystemItem>? children;
  bool isExpanded;

  FileSystemItem({
    required this.name,
    required this.path,
    required this.type,
    this.modified,
    this.size,
    this.children,
    this.isExpanded = false,
  });

  factory FileSystemItem.fromFileSystemEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    final isDirectory = FileSystemEntity.isDirectorySync(entity.path);
    final isFile = FileSystemEntity.isFileSync(entity.path);

    return FileSystemItem(
      name: p.basename(entity.path),
      path: entity.path,
      type: isDirectory
          ? FileSystemItemType.directory
          : FileSystemItemType.file,
      modified: stat.modified,
      size: isFile ? stat.size : null,
    );
  }

  // Create a parent directory item (for navigation)
  factory FileSystemItem.parentDirectory(String currentPath) {
    final parentPath = p.dirname(currentPath);
    return FileSystemItem(
      name: '..',
      path: parentPath,
      type: FileSystemItemType.parent,
    );
  }

  // Get file extension for icons
  String get fileExtension {
    if (type != FileSystemItemType.file) return '';
    final ext = p.extension(p.basename(path));
    return ext.isNotEmpty ? ext.substring(1) : ''; // Remove the dot
  }

  // Check if the item is a code file
  bool get isCodeFile {
    if (type != FileSystemItemType.file) return false;
    final ext = fileExtension.toLowerCase();
    return const [
      'dart',
      'yaml',
      'json',
      'xml',
      'html',
      'css',
      'js',
    ].contains(ext);
  }

  // Toggle expanded state
  void toggleExpanded() {
    if (type == FileSystemItemType.directory) {
      isExpanded = !isExpanded;
    }
  }

  // Read file content as string
  Future<String> readAsString() async {
    if (type != FileSystemItemType.file) {
      throw Exception('Cannot read content of a directory');
    }
    final file = File(path);
    return await file.readAsString();
  }

  // Get file extension for filtering
  String get extension {
    if (type != FileSystemItemType.file) return '';
    final ext = p.extension(name).toLowerCase();
    return ext.isNotEmpty ? ext.substring(1) : ''; // Remove the dot
  }

  // Check if file is supported for outline view
  bool get isSupportedForOutline {
    if (type != FileSystemItemType.file) return false;
    final ext = extension;
    return const [
      'dart',
      'md',
      'markdown',
      'yaml',
      'yml',
      'json',
    ].contains(ext);
  }
}
