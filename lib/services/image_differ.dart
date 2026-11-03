import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_diff_result.dart';
import 'package:image/image.dart' as img;

/// Compares two raster images pixel by pixel, for an image diff's
/// Difference mode.
class ImageDiffer {
  /// Creates the differ.
  const ImageDiffer();

  /// Bytes per RGBA pixel.
  static const int _channels = 4;

  /// Largest value of an 8-bit color channel.
  static const int _channelMax = 0xFF;

  /// Compares the encoded [oldBytes] and [newBytes] on another isolate, or
  /// returns null when either can't be decoded, such as a vector image.
  Future<ImageDiffResult?> compare(Uint8List oldBytes, Uint8List newBytes) =>
      Isolate.run(() => compareSync(oldBytes, newBytes));

  /// Compares the encoded [oldBytes] and [newBytes] on the calling isolate;
  /// see [compare].
  static ImageDiffResult? compareSync(Uint8List oldBytes, Uint8List newBytes) {
    final oldImage = _decodeRgba(oldBytes);
    final newImage = _decodeRgba(newBytes);
    if (oldImage == null || newImage == null) return null;
    final width = oldImage.width > newImage.width
        ? oldImage.width
        : newImage.width;
    final height = oldImage.height > newImage.height
        ? oldImage.height
        : newImage.height;
    final oldPixels = oldImage.getBytes(order: img.ChannelOrder.rgba);
    final newPixels = newImage.getBytes(order: img.ChannelOrder.rgba);
    final highlight = _rgba(AppColor.imageDiffChanged);
    final mask = Uint8List(width * height * _channels);
    var changedPixels = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final inOld = x < oldImage.width && y < oldImage.height;
        final inNew = x < newImage.width && y < newImage.height;
        final changed =
            inOld != inNew ||
            (inOld &&
                !_samePixel(
                  oldPixels,
                  (y * oldImage.width + x) * _channels,
                  newPixels,
                  (y * newImage.width + x) * _channels,
                ));
        if (!changed) continue;
        changedPixels++;
        mask.setRange(
          (y * width + x) * _channels,
          (y * width + x + 1) * _channels,
          highlight,
        );
      }
    }
    return ImageDiffResult(
      mask: mask,
      width: width,
      height: height,
      changedPixels: changedPixels,
      oldSize: (width: oldImage.width, height: oldImage.height),
      newSize: (width: newImage.width, height: newImage.height),
    );
  }

  /// [bytes] decoded as 8-bit RGBA, or null when no decoder reads them.
  static img.Image? _decodeRgba(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    return image?.convert(format: img.Format.uint8, numChannels: _channels);
  }

  /// The 8-bit RGBA bytes of [color].
  static List<int> _rgba(Color color) => [
    for (final channel in [color.r, color.g, color.b, color.a])
      (channel * _channelMax).round(),
  ];

  /// Whether the pixel at [a] in [aPixels] equals the one at [b] in
  /// [bPixels], all four channels alike.
  static bool _samePixel(Uint8List aPixels, int a, Uint8List bPixels, int b) {
    for (var channel = 0; channel < _channels; channel++) {
      if (aPixels[a + channel] != bPixels[b + channel]) return false;
    }
    return true;
  }
}
