import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/models/image_diff_mode.dart';
import 'package:fide/models/image_diff_result.dart';
import 'package:fide/providers/image_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/any_image.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/image_backdrop_buttons.dart';
import 'package:fide/widgets/image_canvas.dart';
import 'package:fide/widgets/image_diff_mode_icon.dart';
import 'package:fide/widgets/image_zoom_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compares the committed and modified versions of an image under a strip
/// picking the [ImageDiffMode], the backdrop and, in Swipe and Onion
/// modes, how far the modified image is revealed; both versions share one
/// zoom and pan.
class ImageDiff extends ConsumerStatefulWidget {
  /// Creates the diff of the image at [path]: [oldBytes] as committed, or
  /// null when it isn't in HEAD, against [newBytes].
  const ImageDiff({
    super.key,
    required this.path,
    required this.oldBytes,
    required this.newBytes,
  });

  /// The modified image, encoded.
  final Uint8List newBytes;

  /// The committed image, encoded; null for a file not in HEAD.
  final Uint8List? oldBytes;

  /// The image file, naming its format.
  final String path;

  @override
  ConsumerState<ImageDiff> createState() => _ImageDiffState();
}

class _ImageDiffState extends ConsumerState<ImageDiff> {
  /// Zoom and pan shared by every canvas of the diff.
  final TransformationController _transformation = TransformationController();

  /// How the two versions are shown.
  ImageDiffMode _mode = ImageDiffMode.twoUp;

  /// Share of the width left of the Swipe divider, showing the modified
  /// image.
  double _swipe = AppOpacity.imageDiffHalfway;

  /// Opacity of the modified image in Onion mode.
  double _onion = AppOpacity.imageDiffHalfway;

  /// The pixel comparison, once made; null before, or when the images
  /// can't be compared (vector images, or no committed version).
  ImageDiffResult? _comparison;

  /// The changed pixels of [_comparison], drawn in Difference mode.
  ui.Image? _mask;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  @override
  void didUpdateWidget(ImageDiff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.oldBytes != widget.oldBytes ||
        oldWidget.newBytes != widget.newBytes) {
      _transformation.value = Matrix4.identity();
      _compare();
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    _mask?.dispose();
    super.dispose();
  }

  /// The modes the images allow: Swipe and Onion need a committed version,
  /// Difference a pixel comparison.
  List<ImageDiffMode> get _modes => [
    ImageDiffMode.twoUp,
    if (widget.oldBytes != null) ...[ImageDiffMode.swipe, ImageDiffMode.onion],
    if (_mask != null) ImageDiffMode.difference,
  ];

  /// Compares the two versions pixel by pixel on another isolate, then
  /// decodes the changed-pixel mask for Difference mode.
  Future<void> _compare() async {
    _mask?.dispose();
    _mask = null;
    _comparison = null;
    final oldBytes = widget.oldBytes;
    if (oldBytes == null) return;
    final comparison = await ref
        .read(imageDifferProvider)
        .compare(oldBytes, widget.newBytes);
    if (!mounted || comparison == null) return;
    final mask = await _decodeMask(comparison);
    if (!mounted) {
      mask.dispose();
      return;
    }
    setState(() {
      _comparison = comparison;
      _mask = mask;
    });
  }

  /// The mask of [comparison] as a drawable image.
  static Future<ui.Image> _decodeMask(ImageDiffResult comparison) async {
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      comparison.mask,
      comparison.width,
      comparison.height,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    return decoded.future;
  }

  @override
  Widget build(BuildContext context) {
    final modes = _modes;
    final mode = modes.contains(_mode) ? _mode : ImageDiffMode.twoUp;
    return Column(
      children: [
        HeaderBar(
          child: Row(
            spacing: AppSpacing.medium,
            children: [
              ChoiceButtons(
                values: modes,
                selected: mode,
                icon: (mode) => mode.icon,
                label: (mode) => mode.label,
                onSelected: (mode) => setState(() => _mode = mode),
              ),
              const ImageBackdropButtons(),
              if (mode == ImageDiffMode.swipe)
                _buildSlider(_swipe, (value) => _swipe = value),
              if (mode == ImageDiffMode.onion)
                _buildSlider(_onion, (value) => _onion = value),
              const Spacer(),
              ImageZoomLabel(controller: _transformation),
            ],
          ),
        ),
        Expanded(child: _buildMode(mode)),
      ],
    );
  }

  /// The slider setting a mode's [value], a share from 0 to 1.
  Widget _buildSlider(double value, ValueChanged<double> onChanged) {
    return SizedBox(
      width: AppSize.imageDiffSliderWidth,
      child: Slider(
        value: value,
        onChanged: (value) => setState(() => onChanged(value)),
      ),
    );
  }

  /// The body of [mode].
  Widget _buildMode(ImageDiffMode mode) {
    final oldBytes = widget.oldBytes;
    final newImage = AnyImage.memory(widget.newBytes, path: widget.path);
    if (mode == ImageDiffMode.twoUp || oldBytes == null) {
      return Row(
        children: [
          Expanded(
            child: _buildSide(
              'Original',
              oldBytes,
              _comparison?.oldSize,
              oldBytes == null
                  ? const EmptyState(message: 'Not in HEAD')
                  : AnyImage.memory(oldBytes, path: widget.path),
            ),
          ),
          const VerticalDivider(
            width: AppSize.borderThin,
            thickness: AppSize.borderThin,
          ),
          Expanded(
            child: _buildSide(
              'Modified',
              widget.newBytes,
              _comparison?.newSize,
              newImage,
            ),
          ),
        ],
      );
    }
    final oldImage = AnyImage.memory(oldBytes, path: widget.path);
    return switch (mode) {
      ImageDiffMode.twoUp => throw StateError('handled above'),
      ImageDiffMode.swipe => _buildCanvas(
        Stack(
          alignment: Alignment.center,
          children: [
            oldImage,
            ClipRect(clipper: _LeftShareClipper(_swipe), child: newImage),
            Positioned.fill(
              child: Align(
                alignment: Alignment.lerp(
                  Alignment.centerLeft,
                  Alignment.centerRight,
                  _swipe,
                )!,
                child: SizedBox(
                  width: AppSize.borderThin,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ImageDiffMode.onion => _buildCanvas(
        Stack(
          alignment: Alignment.center,
          children: [
            oldImage,
            Opacity(opacity: _onion, child: newImage),
          ],
        ),
      ),
      ImageDiffMode.difference => Column(
        children: [
          Expanded(
            child: _buildCanvas(
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: AppOpacity.imageDiffBase, child: newImage),
                  RawImage(image: _mask, fit: BoxFit.contain),
                ],
              ),
            ),
          ),
          _buildCaption(
            // A share as a whole percent, as the zoom label shows one
            '${AppZoom.label(_comparison!.changedShare)} of pixels changed',
          ),
        ],
      ),
    };
  }

  /// One side of 2-up: [image] on its canvas, captioned with its [label],
  /// pixel [size] and byte count.
  Widget _buildSide(
    String label,
    Uint8List? bytes,
    ({int width, int height})? size,
    Widget image,
  ) {
    return Column(
      children: [
        Expanded(child: _buildCanvas(image)),
        _buildCaption(
          [
            label,
            if (size != null) '${size.width} × ${size.height} px',
            if (bytes != null) bytes.length.readableSize,
          ].join(' • '),
        ),
      ],
    );
  }

  /// [child] on the chosen backdrop, zoomed and panned with every other
  /// canvas.
  Widget _buildCanvas(Widget child) {
    return ImageCanvas(
      controller: _transformation,
      backdrop: ref.watch(imageBackdropProvider),
      child: child,
    );
  }

  /// The line of facts under a canvas.
  Widget _buildCaption(String text) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.small),
      child: Text(text, style: AppTextStyle.secondary(context)),
    );
  }
}

/// Clips to the left [share] of the box, for the Swipe mode's reveal.
class _LeftShareClipper extends CustomClipper<Rect> {
  const _LeftShareClipper(this.share);

  /// Share of the width kept, from 0 to 1.
  final double share;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * share, size.height);

  @override
  bool shouldReclip(_LeftShareClipper oldClipper) => oldClipper.share != share;
}
