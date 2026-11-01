/// One of the colors an image is mostly made of.
typedef DominantColor = ({int argb, double share});

/// What FIDE knows about an image file, for the Outline tab: the file,
/// the picture's size and color, and facts specific to its format.
class ImageDetails {
  /// Creates the details of an image.
  const ImageDetails({
    required this.format,
    required this.fileBytes,
    required this.modified,
    this.width,
    this.height,
    this.colorMode,
    this.bitsPerChannel,
    this.frames = 1,
    this.transparentShare,
    this.dominantColors = const [],
    this.formatDetails = const {},
  });

  /// Bits per channel of the [colorMode] channels; null for vector images.
  final int? bitsPerChannel;

  /// How pixels store color, such as `RGBA` or `Indexed (16 colors)`; null
  /// for vector images.
  final String? colorMode;

  /// The colors the image is mostly made of, most common first, with the
  /// share of visible pixels each covers; for vector images, the colors
  /// named most, with their share of the color uses.
  final List<DominantColor> dominantColors;

  /// Size of the file.
  final int fileBytes;

  /// The file format, such as `PNG`.
  final String format;

  /// Facts only some formats have, such as `Interlaced` for PNG or
  /// `Camera` for a JPEG with EXIF data, by label.
  final Map<String, String> formatDetails;

  /// Frames of an animated image, or images of an ICO; 1 for others.
  final int frames;

  /// Height in pixels; null when the file does not say.
  final int? height;

  /// When the file last changed.
  final DateTime modified;

  /// Share of pixels that are not fully opaque, 0 to 1; null when the image
  /// has no alpha channel.
  final double? transparentShare;

  /// Width in pixels; null when the file does not say.
  final int? width;

  /// Width to height in lowest terms, such as `16:9`; null without a size.
  String? get aspectRatio {
    final width = this.width;
    final height = this.height;
    if (width == null || height == null || width == 0 || height == 0) {
      return null;
    }
    final divisor = width.gcd(height);
    return '${width ~/ divisor}:${height ~/ divisor}';
  }
}
