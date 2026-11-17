import 'dart:io';
import 'dart:math';

import 'package:fide/models/image_details.dart';
import 'package:fide/services/image_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('fide_image_'));
  tearDown(() => folder.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final path = p.join(folder.path, name);
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  test('PNG: size, color mode, transparency and dominant colors', () async {
    // Left 3/4 opaque red, right 1/4 transparent
    final image = img.Image(width: 64, height: 32, numChannels: 4);
    for (final pixel in image) {
      pixel.setRgba(255, 0, 0, pixel.x < 48 ? 255 : 0);
    }
    final path = write('logo.png', img.encodePng(image));

    final details = await const ImageInspector().inspect(path);

    expect(details.format, 'PNG');
    expect([details.width, details.height], [64, 32]);
    expect(details.aspectRatio, '2:1');
    expect(details.colorMode, 'RGBA');
    expect(details.bitsPerChannel, 8);
    expect(details.transparentShare, closeTo(0.25, 0.01));
    expect(details.dominantColors, hasLength(1));
    expect(details.dominantColors.single.argb, 0xFFFF0000);
    expect(details.dominantColors.single.share, 1);
    expect(details.formatDetails['Interlaced'], 'No');
  });

  test('ICO: the sizes it holds', () async {
    final path = write(
      'app.ico',
      img.IcoEncoder().encodeImages([
        img.Image(width: 16, height: 16),
        img.Image(width: 32, height: 32),
      ]),
    );

    final details = await const ImageInspector().inspect(path);

    expect(details.format, 'ICO');
    expect(details.formatDetails['Sizes'], '16 px, 32 px');
  });

  test('icoFrame decodes the frame of a size, PNG encoded', () async {
    final path = write(
      'app.ico',
      img.IcoEncoder().encodeImages([
        img.Image(width: 16, height: 16),
        img.Image(width: 32, height: 32),
      ]),
    );

    final frame = await const ImageInspector().icoFrame(path, 32);

    expect(frame, isNotNull);
    expect(img.decodePng(frame!)!.width, 32);
    expect(await const ImageInspector().icoFrame(path, 64), isNull);
    expect(await const ImageInspector().icoFrame('missing.ico', 16), isNull);
  });

  test('SVG: declared size, view box and the colors it names', () async {
    final path = write(
      'icon.svg',
      '<svg width="24" height="24" viewBox="0 0 24 24">'
              '<path fill="#1E78C8"/><path fill="#1e78c8"/><rect fill="#fff"/>'
              '</svg>'
          .codeUnits,
    );

    final details = await const ImageInspector().inspect(path);

    expect(details.format, 'SVG');
    expect([details.width, details.height], [24, 24]);
    expect(details.colorMode, isNull);
    expect(details.formatDetails['View box'], '0 0 24 24');
    expect(details.formatDetails['Elements'], '4');
    expect(
      [for (final c in details.dominantColors) c.argb],
      [0xFF1E78C8, 0xFFFFFFFF],
    );
  });

  test('refuses a file that is not an image', () async {
    final path = write('notes.png', 'text'.codeUnits);

    expect(
      const ImageInspector().inspect(path),
      throwsA(isA<FormatException>()),
    );
  });

  test('samples large images as walking every pixel did', () async {
    // Odd sizes over the sampling limit, so samples skip pixels and wrap
    // rows at uneven points
    final random = Random(7);
    for (final (width, height) in [(333, 257), (1001, 211)]) {
      final image = img.Image(width: width, height: height, numChannels: 4);
      for (final pixel in image) {
        pixel.setRgba(
          random.nextInt(4) * 64,
          random.nextInt(2) * 200,
          random.nextInt(3) * 100,
          random.nextInt(5) == 0 ? random.nextInt(2) * 128 : 255,
        );
      }
      final path = write('noise_$width.png', img.encodePng(image));

      final details = await const ImageInspector().inspect(path);
      final expected = _walkingEveryPixel(
        img.decodePng(File(path).readAsBytesSync())!,
      );

      expect(details.transparentShare, expected.transparentShare);
      expect(details.dominantColors, expected.dominant);
    }
  });
}

/// The transparency and dominant colors of [image] as the inspector found
/// them before sampling by index: walking every pixel to keep each
/// stride-th one, once for each.
({double transparentShare, List<DominantColor> dominant}) _walkingEveryPixel(
  img.Image image,
) {
  Iterable<img.Pixel> samples() sync* {
    final stride = (image.width * image.height / 65536).ceil();
    var index = 0;
    for (final pixel in image) {
      if (index++ % stride == 0) yield pixel;
    }
  }

  var total = 0;
  var transparent = 0;
  for (final pixel in samples()) {
    total++;
    if (pixel.aNormalized < 1) transparent++;
  }
  final counts = <int, int>{};
  final sums = <int, List<int>>{};
  var visible = 0;
  for (final pixel in samples()) {
    if (pixel.aNormalized == 0) continue;
    final r = (pixel.rNormalized * 255).round();
    final g = (pixel.gNormalized * 255).round();
    final b = (pixel.bNormalized * 255).round();
    final key = (r >> 4) << 8 | (g >> 4) << 4 | b >> 4;
    counts.update(key, (count) => count + 1, ifAbsent: () => 1);
    final sum = sums.putIfAbsent(key, () => [0, 0, 0]);
    sum[0] += r;
    sum[1] += g;
    sum[2] += b;
    visible++;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return (
    transparentShare: transparent / total,
    dominant: [
      for (final key in keys.take(ImageInspector.maxDominantColors))
        (
          argb:
              0xFF000000 |
              sums[key]![0] ~/ counts[key]! << 16 |
              sums[key]![1] ~/ counts[key]! << 8 |
              sums[key]![2] ~/ counts[key]!,
          share: counts[key]! / visible,
        ),
    ],
  );
}
