part of 'file_type_utils.dart';

/// Shared utility for getting file icons.
class FileIconUtils {
  /// Returns an icon widget for the provided file item and extension.
  static Widget getFileIcon(
    FileSystemItem item, {
    double size = AppIconSize.medium,
  }) {
    switch (item.fileExtension.toLowerCase()) {
      case 'dart':
        return SvgPicture.asset(
          'assets/file_dart.svg',
          width: size,
          height: size,
        );
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
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return Icon(Icons.css, size: size);
      case 'json':
      case 'arb':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'csv':
      case 'dot':
        return Icon(Icons.data_object, size: size);
      case 'md':
      case 'markdown':
      case 'rst':
      case 'adoc':
        return Icon(Icons.text_snippet, size: size);
      case 'ini':
      case 'cfg':
      case 'conf':
      case 'properties':
      case 'env':
      case 'plist':
      case 'gradle':
        return Icon(Icons.build, size: size);
      case 'lock':
        return Icon(Icons.lock, size: size);
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'fish':
      case 'ps1':
      case 'bat':
      case 'cmd':
        return Icon(Icons.terminal, size: size);
      case 'txt':
      case 'log':
      case 'out':
      case 'gitignore':
      case 'dockerignore':
        return Icon(Icons.article, size: size);
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
      case 'pdf':
        return Icon(Icons.picture_as_pdf, size: size);
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
