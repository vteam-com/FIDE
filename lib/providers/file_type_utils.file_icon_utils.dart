part of 'file_type_utils.dart';

/// Shared utility for getting file icons.
class FileIconUtils {
  /// Returns an icon widget for the provided file item and extension.
  static Widget getFileIcon(
    FileSystemItem item, {
    double size = AppIconSize.medium,
  }) {
    final category = FileTypeUtils.categoryOf(item.fileExtension);
    final fallback = Icon(category.icon, size: size);
    if (category == FileCategory.dart) {
      // A missing asset, e.g. a build cleaned under a running app, falls
      // back to the category icon
      return SvgPicture.asset(
        'assets/file_dart.svg',
        width: size,
        height: size,
        errorBuilder: (_ /*context*/, _ /*error*/, _ /*stackTrace*/) =>
            fallback,
      );
    }
    return fallback;
  }
}
