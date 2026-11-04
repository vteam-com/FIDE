import 'dart:typed_data';

import 'package:flutter/painting.dart';

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

  /// Flag: the user set a height other than the annotation's.
  static const int heightIsAdjustedFlag = 4;

  /// Flag: the user set a width other than the annotation's.
  static const int widthIsAdjustedFlag = 8;

  /// Flag: the width is Auto, set by neither the annotation nor the user.
  static const int widthIsAutoFlag = 16;

  /// Flag: the height is Auto, set by neither the annotation nor the user.
  static const int heightIsAutoFlag = 32;

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

  /// How the host sized the preview: the `...Flag` constants that apply.
  final int flags;

  /// Whether the preview's width depends on the panel's.
  bool get widthFollowsPanel => flags & widthFollowsPanelFlag != 0;

  /// Whether the preview's height is the host's fallback.
  bool get heightIsFallback => flags & heightIsFallbackFlag != 0;

  /// Whether the preview renders at a height the user set, not its code's.
  bool get heightIsAdjusted => flags & heightIsAdjustedFlag != 0;

  /// Whether the preview renders at a width the user set, not its code's.
  bool get widthIsAdjusted => flags & widthIsAdjustedFlag != 0;

  /// Whether the preview's width is Auto: sized by its content, up to the
  /// panel's.
  bool get widthIsAuto => flags & widthIsAutoFlag != 0;

  /// Whether the preview's height is Auto: its natural height, else the
  /// host's fallback.
  bool get heightIsAuto => flags & heightIsAutoFlag != 0;

  /// Whether the code renders the preview at another size than shown: the
  /// user changed its width or height.
  bool get differsFromCode => widthIsAdjusted || heightIsAdjusted;

  /// The preview's width ([Axis.horizontal]) or height.
  double lengthAlong(Axis axis) =>
      axis == Axis.horizontal ? size.width : size.height;

  /// Whether the preview's width ([Axis.horizontal]) or height is Auto.
  bool isAutoAlong(Axis axis) =>
      axis == Axis.horizontal ? widthIsAuto : heightIsAuto;

  /// The preview's width when fixed; null when Auto.
  double? get fixedWidth => widthIsAuto ? null : size.width;

  /// The preview's height when fixed; null when Auto.
  double? get fixedHeight => heightIsAuto ? null : size.height;

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
