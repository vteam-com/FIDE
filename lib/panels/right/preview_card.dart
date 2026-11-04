import 'package:fide/constants/constants.dart';
import 'package:fide/models/preview_frame.dart';
import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_pointer_phase.dart';
import 'package:fide/models/preview_size_step.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/preview_size_fixer.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/image_backdrop_box.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One preview in the Preview panel: its title, which shows its code, and
/// its latest frame, which takes clicks, drags and scrolls as the widget
/// would, on the backdrop picked for images. Its width and height are each Auto or fixed, as the developer
/// picks: grips on the right of and under the frame resize it by
/// [PreviewSizeStep.step], and Fix Size writes the size shown in the code.
class PreviewCard extends ConsumerStatefulWidget {
  /// Creates the card of [item], the preview at [index] declared in
  /// [path], drawn at [zoom].
  const PreviewCard({
    super.key,
    required this.path,
    required this.item,
    required this.index,
    required this.zoom,
    this.onFixSize,
  });

  /// The file declaring the preview.
  final String path;

  /// The preview.
  final PreviewItem item;

  /// The preview's position in the host's list.
  final int index;

  /// How much larger than its logical size the frame is drawn.
  final double zoom;

  /// Writes the size the preview renders at in its annotation; null when
  /// the size can't be written there.
  final VoidCallback? onFixSize;

  @override
  ConsumerState<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends ConsumerState<PreviewCard> {
  /// The length each grip's drag reached, unsnapped, by axis; absent when
  /// not dragging.
  final Map<Axis, double> _dragged = {};

  /// The length last sent to the host during each grip's drag.
  final Map<Axis, double> _sent = {};

  PreviewController get _controller =>
      ref.read(previewControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final frame = item.frame;
    return OutlinedSurface(
      padding: SurfacePadding.dense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.small,
        children: [
          Row(
            children: [
              Expanded(
                child: Clickable(
                  onTap: () => openFileAtLine(ref, widget.path, item.line),
                  child: Tooltip(
                    message: 'Show ${item.function} in the editor',
                    child: Text(
                      item.title,
                      style: AppTextStyle.captionStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (frame != null) ...[
                _buildLength(frame, Axis.horizontal),
                _buildLength(frame, Axis.vertical),
                if (widget.onFixSize case final fix?)
                  CompactIconButton(
                    icon: Icons.straighten,
                    tooltip: _fixSizeTooltip(frame),
                    // Always there, so resizing never moves the buttons
                    onPressed: frame.differsFromCode ? fix : null,
                  ),
              ],
            ],
          ),
          if (frame == null) const InlineSpinner() else _buildResizable(frame),
        ],
      ),
    );
  }

  /// The frame, with the grip resizing its width on its right and the
  /// one resizing its height under it.
  Widget _buildResizable(PreviewFrame frame) {
    final size = frame.size * widget.zoom;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildFrame(size, frame.png),
              ),
              SizedBox(
                width: size.width,
                child: _buildGrip(frame, Axis.vertical),
              ),
            ],
          ),
        ),
        SizedBox(
          height: size.height,
          child: _buildGrip(frame, Axis.horizontal),
        ),
      ],
    );
  }

  /// The grip dragging [frame]'s preview along [axis].
  Widget _buildGrip(PreviewFrame frame, Axis axis) => ResizableSplitter(
    isHorizontal: axis == Axis.vertical,
    showsGripAtRest: true,
    onResize: (delta) => _drag(axis, frame.lengthAlong(axis), delta),
    onResizeEnd: () {
      _dragged.remove(axis);
      _sent.remove(axis);
    },
  );

  /// Grows the preview's [length] along [axis], when the drag started, by
  /// the grip's [delta] in panel pixels, a step at a time.
  void _drag(Axis axis, double length, double delta) {
    final dragged = _dragged[axis] =
        (_dragged[axis] ?? length) + delta / widget.zoom;
    final snapped = PreviewSizeStep.snap(dragged);
    if (snapped == (_sent[axis] ?? length)) return;
    _sent[axis] = snapped;
    _controller.resize(widget.index, axis, snapped);
  }

  /// The preview's width ([Axis.horizontal]) or height: Auto or its
  /// length, switching between the two.
  Widget _buildLength(PreviewFrame frame, Axis axis) {
    final isAuto = frame.isAutoAlong(axis);
    final fit = PreviewSizeStep.fit(frame.lengthAlong(axis));
    return CompactTextButton(
      icon: axis == Axis.horizontal ? Icons.swap_horiz : Icons.swap_vert,
      label: isAuto ? 'Auto' : '${frame.lengthAlong(axis).round()}',
      tooltip: _lengthTooltip(frame, axis, fit),
      onPressed: () =>
          _controller.resize(widget.index, axis, isAuto ? fit : null),
    );
  }

  /// What [frame]'s width ([Axis.horizontal]) or height is, and what a
  /// click makes of it: [fit] when Auto.
  static String _lengthTooltip(PreviewFrame frame, Axis axis, double fit) {
    final isWidth = axis == Axis.horizontal;
    final name = isWidth ? 'Width' : 'Height';
    if (!frame.isAutoAlong(axis)) {
      final grip = isWidth ? 'on the right of' : 'under';
      return '$name: ${frame.lengthAlong(axis).round()}. Click for Auto, or '
          'drag the grip $grip the preview';
    }
    final why = isWidth
        ? (frame.widthFollowsPanel ? 'follows the panel' : 'fits its content')
        : (frame.heightIsFallback
              ? 'a default, as it has no natural height'
              : 'its natural height');
    return '$name: Auto, $why. Click to fix it at ${fit.round()}, to fit';
  }

  /// What Fix Size writes for [frame], or why it has nothing to write.
  static String _fixSizeTooltip(PreviewFrame frame) {
    if (!frame.differsFromCode) {
      return 'Fix Size in Code: the code sets this size; resize the preview '
          'or switch its width or height to change it';
    }
    final argument = PreviewSizeFixer.sizeArgumentFor(
      width: frame.fixedWidth,
      height: frame.fixedHeight,
    );
    return 'Fix Size in Code: writes ${argument ?? 'no size, both Auto'}';
  }

  /// The frame's image at [size], forwarding the pointer to the preview.
  Widget _buildFrame(Size size, Uint8List png) {
    final zoom = widget.zoom;
    void send(PreviewPointerPhase phase, Offset position, [Offset? scroll]) =>
        _controller.pointer(
          widget.index,
          phase,
          position / zoom,
          scroll: (scroll ?? Offset.zero) / zoom,
        );
    return Listener(
      onPointerDown: (event) =>
          send(PreviewPointerPhase.down, event.localPosition),
      onPointerMove: (event) =>
          send(PreviewPointerPhase.move, event.localPosition),
      onPointerUp: (event) => send(PreviewPointerPhase.up, event.localPosition),
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          send(
            PreviewPointerPhase.scroll,
            event.localPosition,
            event.scrollDelta,
          );
        }
      },
      child: ImageBackdropBox(
        backdrop: ref.watch(imageBackdropProvider),
        child: Image.memory(
          png,
          width: size.width,
          height: size.height,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
