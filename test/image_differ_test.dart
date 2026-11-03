import 'dart:typed_data';

import 'package:fide/constants/constants.dart';
import 'package:fide/services/image_differ.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A [width] by [height] PNG filled with [color], the pixel at (0, 0)
/// painted [corner] when given.
Uint8List _png(int width, int height, img.Color color, {img.Color? corner}) {
  final image = img.Image(width: width, height: height, numChannels: 4)
    ..clear(color);
  if (corner != null) image.setPixel(0, 0, corner);
  return img.encodePng(image);
}

void main() {
  final red = img.ColorRgba8(255, 0, 0, 255);
  final blue = img.ColorRgba8(0, 0, 255, 255);

  group('ImageDiffer', () {
    test('identical images leave the mask transparent', () {
      final result = ImageDiffer.compareSync(_png(2, 2, red), _png(2, 2, red));

      expect(result!.changedPixels, 0);
      expect(result.changedShare, 0);
      expect(result.mask.every((byte) => byte == 0), isTrue);
      expect(result.oldSize, (width: 2, height: 2));
    });

    test('a changed pixel is highlighted and counted', () {
      final result = ImageDiffer.compareSync(
        _png(2, 2, red),
        _png(2, 2, red, corner: blue),
      );

      expect(result!.changedPixels, 1);
      expect(result.changedShare, 0.25);
      final highlight = AppColor.imageDiffChanged;
      expect(result.mask.sublist(0, 4), [
        (highlight.r * 255).round(),
        (highlight.g * 255).round(),
        (highlight.b * 255).round(),
        (highlight.a * 255).round(),
      ]);
      expect(result.mask.sublist(4).every((byte) => byte == 0), isTrue);
    });

    test('pixels outside the smaller image count as changed', () {
      final result = ImageDiffer.compareSync(_png(1, 1, red), _png(2, 1, red));

      expect((result!.width, result.height), (2, 1));
      expect(result.changedPixels, 1);
      expect(result.newSize, (width: 2, height: 1));
    });

    test('undecodable bytes give no comparison', () {
      expect(
        ImageDiffer.compareSync(Uint8List.fromList([1, 2, 3]), _png(1, 1, red)),
        isNull,
      );
    });
  });
}
