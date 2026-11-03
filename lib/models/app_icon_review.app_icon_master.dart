part of 'app_icon_review.dart';

/// The image every app icon is generated from, and whether it is good
/// enough: square and at least [recommendedSize] wide.
class AppIconMaster {
  /// Smallest master no icon is upscaled from: the iOS App Store icon.
  static const int recommendedSize = fcheck.AppIconChecker.appStoreIconSize;

  /// Height in pixels; null when the image can't be read.
  final int? height;

  /// Absolute path of the image.
  final String path;

  /// Width in pixels; null when the image can't be read.
  final int? width;

  /// Creates the master at [path], [width] by [height] pixels when it
  /// could be read.
  const AppIconMaster(this.path, {this.width, this.height});

  /// Whether the image is wider than tall or taller than wide, so only
  /// its center square is used.
  bool get isNotSquare => isReadable && width != height;

  /// Whether the image could be decoded.
  bool get isReadable => width != null && height != null;

  /// Whether the largest icons would be upscaled from it, blurring them.
  bool get isTooSmall =>
      isReadable && (width! < recommendedSize || height! < recommendedSize);
}
