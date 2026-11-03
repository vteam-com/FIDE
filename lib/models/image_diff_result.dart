import 'dart:typed_data';

/// The pixel comparison of two raster images: a mask of the pixels that
/// differ and how many of them there are.
class ImageDiffResult {
  /// Creates the comparison.
  const ImageDiffResult({
    required this.mask,
    required this.width,
    required this.height,
    required this.changedPixels,
    required this.oldSize,
    required this.newSize,
  });

  /// RGBA pixels, [width] by [height]: the highlight color where the images
  /// differ, transparent where they match.
  final Uint8List mask;

  /// Width of [mask]: the wider image's.
  final int width;

  /// Height of [mask]: the taller image's.
  final int height;

  /// How many pixels of [mask] differ, pixels outside the smaller image
  /// included.
  final int changedPixels;

  /// Width and height of the committed image.
  final ({int width, int height}) oldSize;

  /// Width and height of the modified image.
  final ({int width, int height}) newSize;

  /// The share of [mask] that differs, 0 for identical images and 1 for
  /// wholly different ones.
  double get changedShare => changedPixels / (width * height);
}
