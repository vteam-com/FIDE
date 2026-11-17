import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// A raster image fitted inside its box, drawn as macOS Preview draws one:
/// each image pixel a sharp square once enlarged on screen (an icon, a
/// zoomed-in image), smoothed only when shrunk. The on-screen scale counts
/// the box's fit, every zoom above it and the display's pixel ratio.
class PixelImage extends StatefulWidget {
  /// Creates the image [image] loads, [width] by [height] when given.
  const PixelImage(
    this.image, {
    super.key,
    this.width,
    this.height,
    this.errorBuilder,
  });

  /// Shown in place of an image that fails to load; nothing when null.
  final WidgetBuilder? errorBuilder;

  /// Height of the box; the image's when null.
  final double? height;

  /// Loads the image.
  final ImageProvider image;

  /// Width of the box; the image's when null.
  final double? width;

  @override
  State<PixelImage> createState() => _PixelImageState();
}

class _PixelImageState extends State<PixelImage> {
  /// Why the image failed to load; null when it didn't.
  Object? _error;

  /// The last frame loaded; null while loading.
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onFrame,
    onError: (error, _) => setState(() => _error = error),
  );

  /// The stream the image loads from.
  ImageStream? _stream;
  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PixelImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context) ?? const SizedBox();
    }
    final info = _info;
    return PixelRawImage(
      image: info?.image,
      scale: info?.scale ?? PixelRawImage.unitScale,
      width: widget.width,
      height: widget.height,
    );
  }

  /// Shows [info], a new frame of the image.
  void _onFrame(ImageInfo info, bool _) {
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  /// Listens to the stream of [PixelImage.image], forgetting the previous
  /// image's frame and error.
  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _info?.dispose();
    _info = null;
    _error = null;
    _stream = stream..addListener(_listener);
  }
}

/// A decoded [image] fitted inside its box, drawn with sharp pixels when
/// enlarged on screen and smoothed when shrunk: see [PixelImage].
class PixelRawImage extends RawImage {
  /// Creates the drawing of [image], [width] by [height] when given.
  const PixelRawImage({
    super.key,
    required super.image,
    super.width,
    super.height,
    super.scale,
  }) : super(fit: BoxFit.contain);

  /// The scale at which one image pixel covers one screen pixel.
  static const double unitScale = 1;

  @override
  RenderImage createRenderObject(BuildContext context) {
    return _RenderPixelImage(
      image: image?.clone(),
      width: width,
      height: height,
      scale: scale,
      fit: fit,
      textDirection: Directionality.maybeOf(context),
    );
  }
}

/// Paints its image with the filter its on-screen scale calls for, found
/// at each paint so that zooming a canvas above it switches the filter.
class _RenderPixelImage extends RenderImage {
  _RenderPixelImage({
    super.image,
    super.width,
    super.height,
    super.scale,
    super.fit,
    super.textDirection,
  });

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = this.image;
    if (image == null) return;
    final drawn = applyBoxFit(
      fit ?? BoxFit.contain,
      Size(image.width / scale, image.height / scale),
      size,
    ).destination;
    // From the box to the screen: zooms above it and the pixel ratio
    final screenScale = getTransformTo(null).getMaxScaleOnAxis();
    final enlarged =
        drawn.width * screenScale / image.width >= PixelRawImage.unitScale;
    paintImage(
      canvas: context.canvas,
      rect: offset & size,
      image: image,
      scale: scale,
      fit: fit,
      alignment: alignment.resolve(textDirection),
      filterQuality: enlarged ? FilterQuality.none : FilterQuality.medium,
    );
  }
}
