import 'dart:typed_data';

import 'package:fide/providers/image_providers.dart';
import 'package:fide/widgets/pixel_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The image of one [size] embedded in the ICO file at [path], drawn
/// [drawnSize] wide, its pixels sharp when enlarged, or [fallback] when the
/// file holds no such image.
class IcoFrameImage extends ConsumerStatefulWidget {
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
  ConsumerState<IcoFrameImage> createState() => _IcoFrameImageState();
}

class _IcoFrameImageState extends ConsumerState<IcoFrameImage> {
  /// The frame as PNG bytes; null when missing.
  late Future<Uint8List?> _frame;

  @override
  void initState() {
    super.initState();
    _frame = _decode();
  }

  @override
  void didUpdateWidget(IcoFrameImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.size != widget.size) {
      _frame = _decode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _frame,
      builder: (_, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return widget.fallback;
        return PixelImage(
          MemoryImage(bytes),
          width: widget.drawnSize,
          height: widget.drawnSize,
        );
      },
    );
  }

  /// Starts decoding the frame off the UI thread.
  Future<Uint8List?> _decode() =>
      ref.read(imageInspectorProvider).icoFrame(widget.path, widget.size);
}
