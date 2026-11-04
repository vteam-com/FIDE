import 'dart:typed_data';
import 'dart:ui';

/// A rendered image of one preview, as the preview host sends it: a
/// header of [headerBytes] (generation, index, logical width and height,
/// sizing flags), then the PNG.
class PreviewFrame {
  /// Creates the frame.
  const PreviewFrame({
    required this.generation,
    required this.index,
    required this.size,
    required this.png,
    this.flags = 0,
  });

  /// Bytes before the PNG.
  static const int headerBytes = 20;

  /// Flag: the preview sets no width and fills the panel's.
  static const int widthFollowsPanelFlag = 1;

  /// Flag: the preview sets no height and has no natural one.
  static const int heightIsFallbackFlag = 2;

  static const int _flagsOffset = 16;

  static const int _indexOffset = 4;
  static const int _widthOffset = 8;
  static const int _heightOffset = 12;

  /// The preview list the frame belongs to; frames of an older list are
  /// dropped.
  final int generation;

  /// The preview's position in its list.
  final int index;

  /// The preview's logical size.
  final Size size;

  /// The image, PNG encoded.
  final Uint8List png;

  /// How the host sized the preview: [widthFollowsPanelFlag] and
  /// [heightIsFallbackFlag] when they apply.
  final int flags;

  /// Whether the preview's width depends on the panel's.
  bool get widthFollowsPanel => flags & widthFollowsPanelFlag != 0;

  /// Whether the preview's height is the host's fallback.
  bool get heightIsFallback => flags & heightIsFallbackFlag != 0;

  /// Whether the code doesn't determine the preview's size, so it changes
  /// with the panel or the host's defaults.
  bool get isSizeUndetermined => widthFollowsPanel || heightIsFallback;

  /// The frame in host message [bytes], or null when they are too short to
  /// hold one.
  static PreviewFrame? decode(List<int> bytes) {
    if (bytes.length <= headerBytes) return null;
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final header = ByteData.sublistView(data, 0, headerBytes);
    return PreviewFrame(
      generation: header.getUint32(0),
      index: header.getUint32(_indexOffset),
      size: Size(
        header.getFloat32(_widthOffset),
        header.getFloat32(_heightOffset),
      ),
      png: Uint8List.sublistView(data, headerBytes),
      flags: header.getUint32(_flagsOffset),
    );
  }
}
