import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fcheck/fcheck.dart' show AppIconFileInfo;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_details.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:image/image.dart' as img;

/// Reads an image file's [ImageDetails]: raster formats are decoded with
/// the `image` package, SVG files read as text.
class ImageInspector {
  /// Creates a stateless inspector.
  const ImageInspector();

  /// Dominant colors listed.
  static const int maxDominantColors = 5;

  /// Pixels sampled at most to find the dominant colors.
  static const int _maxSamples = 65536;

  /// Bits dropped from each channel to group similar colors.
  static const int _colorBucketShift = 4;

  /// Bits per channel kept in a color bucket key.
  static const int _bucketBits = 8 - _colorBucketShift;

  /// Shift of the red bucket bits in a color bucket key.
  static const int _redBucketShift = 2 * _bucketBits;

  /// Color modes by number of channels.
  static const Map<int, String> _channelModes = {
    1: 'Gray',
    2: 'Gray + alpha',
    3: 'RGB',
    4: 'RGBA',
  };

  /// Channel counts that include alpha.
  static const Set<int> _alphaChannelCounts = {2, 4};

  /// Indexes of red, green and blue in a list of channels.
  static const int _red = 0;
  static const int _green = 1;
  static const int _blue = 2;

  /// An SVG view box: min x, min y, width and height.
  static const int _viewBoxValues = 4;
  static const int _viewBoxWidth = 2;
  static const int _viewBoxHeight = 3;

  /// Shift of each channel in a color, red highest.
  static const int _redShift = 16;
  static const int _greenShift = 8;

  /// Decimals of a PNG gamma.
  static const int _gammaDecimals = 2;

  /// Converts PNG pixels per meter to dots per inch.
  static const double _inchesPerMeter = 0.0254;

  /// Extension of vector images.
  static const String _svgExtension = 'svg';

  /// The `<svg>` root element of an SVG file.
  static final RegExp _svgRoot = RegExp(r'<svg\b[^>]*>', caseSensitive: false);

  /// Any XML element start, to count an SVG's elements.
  static final RegExp _svgElement = RegExp(r'<[a-zA-Z]');

  /// A hexadecimal color in an SVG, such as `#1e78c8`.
  static final RegExp _svgHexColor = RegExp(
    r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b',
  );

  /// Short hexadecimal colors have one digit per channel.
  static const int _shortHexLength = 3;

  /// Base of hexadecimal digits.
  static const int _hexRadix = 16;

  /// Opaque alpha of an ARGB color.
  static const int _opaque = 0xFF000000;

  /// The details of the image at [path], read off the UI thread.
  ///
  /// Throws [FileSystemException] when the file can't be read and
  /// [FormatException] when it isn't an image FIDE can read.
  Future<ImageDetails> inspect(String path) => Isolate.run(() {
    final file = File(path);
    final bytes = file.readAsBytesSync();
    final modified = file.lastModifiedSync();
    return FileTypeUtils.extensionOf(path) == _svgExtension
        ? _svg(String.fromCharCodes(bytes), bytes.length, modified)
        : _raster(file, bytes, modified);
  });

  /// The details of the raster image in [bytes].
  static ImageDetails _raster(File file, Uint8List bytes, DateTime modified) {
    final decoder = img.findDecoderForData(bytes);
    final image = decoder?.decode(bytes);
    if (decoder == null || image == null) {
      throw const FormatException('Not an image FIDE can read');
    }
    final format = img.findFormatForData(bytes);
    final palette = image.palette;
    final hasAlpha = _alphaChannelCounts.contains(image.numChannels);
    return ImageDetails(
      format: format.name.toUpperCase(),
      fileBytes: bytes.length,
      modified: modified,
      width: image.width,
      height: image.height,
      colorMode: palette != null
          ? 'Indexed (${palette.numColors} colors)'
          : _channelModes[image.numChannels] ?? '${image.numChannels} channels',
      bitsPerChannel: image.bitsPerChannel,
      frames: image.numFrames,
      transparentShare:
          hasAlpha || _alphaChannelCounts.contains(palette?.numChannels)
          ? _transparentShare(image)
          : null,
      dominantColors: _dominantColors(image),
      formatDetails: {
        ..._pngDetails(decoder),
        ..._icoDetails(decoder, file),
        ..._exifDetails(image),
      },
    );
  }

  /// Every [stride]-th pixel of [image], so at most about [_maxSamples].
  static Iterable<img.Pixel> _samples(img.Image image) sync* {
    final stride = (image.width * image.height / _maxSamples).ceil();
    var index = 0;
    for (final pixel in image) {
      if (index++ % stride == 0) yield pixel;
    }
  }

  /// Share of sampled pixels that are not fully opaque.
  static double _transparentShare(img.Image image) {
    var total = 0;
    var transparent = 0;
    for (final pixel in _samples(image)) {
      total++;
      if (pixel.aNormalized < 1) transparent++;
    }
    return total == 0 ? 0 : transparent / total;
  }

  /// The [maxDominantColors] commonest colors of [image]'s visible pixels,
  /// similar colors grouped and averaged.
  static List<DominantColor> _dominantColors(img.Image image) {
    final counts = <int, int>{};
    final sums = <int, List<int>>{};
    var visible = 0;
    for (final pixel in _samples(image)) {
      if (pixel.aNormalized == 0) continue;
      final r = (pixel.rNormalized * AppMetric.colorChannelMax).round();
      final g = (pixel.gNormalized * AppMetric.colorChannelMax).round();
      final b = (pixel.bNormalized * AppMetric.colorChannelMax).round();
      final key =
          (r >> _colorBucketShift) << _redBucketShift |
          (g >> _colorBucketShift) << _bucketBits |
          b >> _colorBucketShift;
      counts.update(key, (count) => count + 1, ifAbsent: () => 1);
      final sum = sums.putIfAbsent(key, () => [0, 0, 0]);
      sum[_red] += r;
      sum[_green] += g;
      sum[_blue] += b;
      visible++;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [
      for (final key in keys.take(maxDominantColors))
        (
          argb: _argb([
            for (final channel in sums[key]!) channel ~/ counts[key]!,
          ]),
          share: counts[key]! / visible,
        ),
    ];
  }

  /// The opaque color of red, green and blue [channels].
  static int _argb(List<int> channels) =>
      _opaque |
      channels[_red] << _redShift |
      channels[_green] << _greenShift |
      channels[_blue];

  /// PNG-only facts: bit depth layout, interlacing, resolution, gamma and
  /// text chunks.
  static Map<String, String> _pngDetails(img.Decoder decoder) {
    if (decoder is! img.PngDecoder) return const {};
    final info = decoder.info;
    final dimensions = info.pixelDimensions;
    return {
      'Interlaced': info.interlaceMethod == 0 ? 'No' : 'Adam7',
      if (dimensions != null &&
          dimensions.unitSpecifier == img.PngPhysicalPixelDimensions.unitMeter)
        'Resolution':
            '${(dimensions.xPxPerUnit * _inchesPerMeter).round()} DPI',
      'Gamma': ?info.gamma?.toStringAsFixed(_gammaDecimals),
      if (info.iccpName.isNotEmpty) 'Color profile': info.iccpName,
      if (info.isAnimated)
        'Loops': info.repeat == 0 ? 'Forever' : '${info.repeat}',
      for (final MapEntry(:key, :value) in info.textData.entries) key: value,
    };
  }

  /// ICO-only facts: the sizes [file] holds.
  static Map<String, String> _icoDetails(img.Decoder decoder, File file) {
    if (decoder is! img.IcoDecoder) return const {};
    final sizes = AppIconFileInfo.read(file)?.icoSizes ?? const <int>{};
    return {
      'Sizes': [for (final size in sizes.toList()..sort()) '$size px']
          .join(', '),
    };
  }

  /// The camera, software and author EXIF data of [image], if any.
  static Map<String, String> _exifDetails(img.Image image) {
    final ifd = image.exif.imageIfd;
    final camera = [ifd.make, ifd.model].whereType<String>().join(' ').trim();
    return {
      if (camera.isNotEmpty) 'Camera': camera,
      'Software': ?ifd.software,
      'Description': ?ifd.imageDescription,
      'Copyright': ?ifd.copyright,
      if (ifd.orientation case final orientation?)
        'Orientation': '$orientation',
    };
  }

  /// The details of the SVG [text], [length] bytes long: its declared size,
  /// view box, element count and the colors it names most.
  static ImageDetails _svg(String text, int length, DateTime modified) {
    final root = _svgRoot.firstMatch(text)?.group(0) ?? '';
    String? attribute(String name) =>
        RegExp('\\b$name\\s*=\\s*["\']([^"\']*)["\']')
            .firstMatch(root)
            ?.group(1);
    int? pixels(String? value) => value == null
        ? null
        : double.tryParse(value.replaceAll('px', ''))?.round();

    final viewBox = attribute('viewBox');
    final box = viewBox?.split(RegExp(r'[\s,]+'));
    final counts = <int, int>{};
    for (final match in _svgHexColor.allMatches(text)) {
      var hex = match.group(1)!;
      if (hex.length == _shortHexLength) {
        hex = hex.split('').map((digit) => '$digit$digit').join();
      }
      final argb = _opaque | int.parse(hex, radix: _hexRadix);
      counts.update(argb, (count) => count + 1, ifAbsent: () => 1);
    }
    final total = counts.values.fold(0, (sum, count) => sum + count);
    final colors = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return ImageDetails(
      format: 'SVG',
      fileBytes: length,
      modified: modified,
      width:
          pixels(attribute('width')) ??
          (box?.length == _viewBoxValues ? pixels(box![_viewBoxWidth]) : null),
      height:
          pixels(attribute('height')) ??
          (box?.length == _viewBoxValues ? pixels(box![_viewBoxHeight]) : null),
      dominantColors: [
        for (final argb in colors.take(maxDominantColors))
          (argb: argb, share: counts[argb]! / total),
      ],
      formatDetails: {
        'Vector': 'Scales to any size',
        'View box': ?viewBox,
        'Elements': '${_svgElement.allMatches(text).length}',
      },
    );
  }
}
