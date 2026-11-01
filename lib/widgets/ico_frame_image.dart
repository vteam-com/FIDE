import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// The image of one [size] embedded in the ICO file at [path], drawn
/// [drawnSize] wide, or [fallback] when the file holds no such image.
class IcoFrameImage extends StatefulWidget {
  /// Creates the image of [path]'s [size]-pixel frame.
  const IcoFrameImage({
    super.key,
    required this.path,
    required this.size,
    required this.drawnSize,
    required this.fallback,
  });

  /// Width and height the image is drawn at.
  final double drawnSize;

  /// Shown while decoding and when the frame is missing.
  final Widget fallback;

  /// The ICO file.
  final String path;

  /// Pixel size of the frame shown.
  final int size;

  @override
  State<IcoFrameImage> createState() => _IcoFrameImageState();
}

class _IcoFrameImageState extends State<IcoFrameImage> {
  /// The frame as PNG bytes; null when missing.
  late Future<Uint8List?> _frame;

  /// An ICO directory entry's size byte of zero means this many pixels.
  static const int _zeroSize = 256;
  @override
  void initState() {
    super.initState();
    _frame = _decode(widget.path, widget.size);
  }

  @override
  void didUpdateWidget(IcoFrameImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.size != widget.size) {
      _frame = _decode(widget.path, widget.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _frame,
      builder: (_, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return widget.fallback;
        return Image.memory(
          bytes,
          width: widget.drawnSize,
          height: widget.drawnSize,
          fit: BoxFit.contain,
        );
      },
    );
  }

  /// The [size]-pixel frame of the ICO at [path] as PNG, decoded off the
  /// UI thread; null when it holds none.
  static Future<Uint8List?> _decode(String path, int size) => Isolate.run(() {
    try {
      final decoder = img.IcoDecoder();
      final info = decoder.startDecode(File(path).readAsBytesSync());
      if (info is! img.IcoInfo) return null;
      for (var i = 0; i < info.images.length; i++) {
        final width = info.images[i].width;
        if ((width == 0 ? _zeroSize : width) != size) continue;
        final frame = decoder.decodeFrame(i);
        return frame == null ? null : img.encodePng(frame);
      }
    } on FileSystemException {
      return null;
    }
    return null;
  });
}
