import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared utility for getting file icons.
class FileIconUtils {
  /// The icon of the type of the file at [path].
  static Widget ofPath(String path, {double size = AppIconSize.medium}) =>
      getFileIcon(FileSystemItem.fromPath(path), size: size);

  /// Returns an icon widget for the provided file item and extension.
  static Widget getFileIcon(
    FileSystemItem item, {
    double size = AppIconSize.medium,
  }) {
    final category = !item.isDirectory
        ? FileTypeUtils.categoryOf(FileTypeUtils.extensionOf(item.path))
        : FileCategory.other;
    final fallback = Icon(iconOf(category), size: size);
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

  /// Glyph shown for [category]; [FileCategory.dart] shows the bundled Dart
  /// logo instead, falling back to this glyph.
  static IconData iconOf(FileCategory category) => switch (category) {
    FileCategory.dart => Icons.code,
    FileCategory.source => Icons.developer_mode,
    FileCategory.javascript => Icons.javascript,
    FileCategory.markup => Icons.code,
    FileCategory.stylesheet => Icons.css,
    FileCategory.data => Icons.data_object,
    FileCategory.document => Icons.text_snippet,
    FileCategory.config => Icons.build,
    FileCategory.lock => Icons.lock,
    FileCategory.script => Icons.terminal,
    FileCategory.text => Icons.article,
    FileCategory.image => Icons.image,
    FileCategory.pdf => Icons.picture_as_pdf,
    FileCategory.archive => Icons.archive,
    FileCategory.other => Icons.insert_drive_file,
  };
}
