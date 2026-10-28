part of 'file_type_utils.dart';

/// Shared utility for getting file icons.
class FileIconUtils {
  /// Returns an icon widget for the provided file item and extension.
  static Widget getFileIcon(
    FileSystemItem item, {
    double size = AppIconSize.medium,
  }) {
    final category = FileTypeUtils.categoryOf(item.fileExtension);
    if (category == FileCategory.dart) {
      return SvgPicture.asset(
        'assets/file_dart.svg',
        width: size,
        height: size,
      );
    }
    return Icon(category.icon, size: size);
  }
}
