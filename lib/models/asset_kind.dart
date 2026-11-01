import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// What an asset is for, which groups it in the Organized view's Assets
/// section; values are in display order.
enum AssetKind {
  /// Pictures: photos, illustrations, backgrounds.
  images('Images', Icons.image_outlined, {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'svg',
    'tif',
    'tiff',
    'heic',
  }),

  /// App icons, logos and glyphs: `.ico` files, and images in a folder or
  /// file named after icons or logos.
  icons('Icons', Icons.interests_outlined, {'ico'}),

  /// Font files.
  fonts('Fonts', Icons.font_download_outlined, {'ttf', 'otf', 'woff', 'woff2'}),

  /// Rive and Lottie animations, including Lottie JSON in an animation
  /// folder.
  animations('Animations', Icons.animation, {'riv', 'lottie'}),

  /// Sound effects and music.
  audio('Audio', Icons.audiotrack_outlined, {
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
    'flac',
  }),

  /// Video clips.
  video('Video', Icons.movie_outlined, {'mp4', 'mov', 'webm', 'mkv', 'avi'}),

  /// Data and text the app loads.
  data('Data', Icons.data_object, {
    'json',
    'yaml',
    'yml',
    'csv',
    'txt',
    'xml',
    'md',
  }),

  /// Anything else.
  other('Other', Icons.insert_drive_file_outlined, {});

  /// Group title.
  final String label;

  /// Group icon.
  final IconData icon;

  /// Lowercase extensions, without the dot, that belong to this kind.
  final Set<String> extensions;

  const AssetKind(this.label, this.icon, this.extensions);

  /// Path parts naming icon folders or files, such as `icons/` or `logo.png`.
  static final RegExp _iconHint = RegExp(r'icon|logo', caseSensitive: false);

  /// Path parts naming animation folders, such as `lottie/`.
  static final RegExp _animationHint = RegExp(
    r'lottie|animation',
    caseSensitive: false,
  );

  /// The kind of the asset at project-relative [relativePath], read from
  /// its extension and the names of its file and folders.
  static AssetKind of(String relativePath) {
    final extension = p
        .extension(relativePath)
        .replaceFirst('.', '')
        .toLowerCase();
    final kind = values.firstWhere(
      (kind) => kind.extensions.contains(extension),
      orElse: () => other,
    );
    if (kind == images && _iconHint.hasMatch(relativePath)) return icons;
    if (kind == data &&
        extension == 'json' &&
        _animationHint.hasMatch(relativePath)) {
      return animations;
    }
    return kind;
  }
}
