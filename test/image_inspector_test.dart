import 'dart:io';

import 'package:fide/providers/image_inspector.dart';
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
}
