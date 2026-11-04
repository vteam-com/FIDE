import 'package:fide/constants/constants.dart';
import 'package:fide/models/preview_frame.dart';
import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_pointer_phase.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:fide/services/preview_size_fixer.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One preview in the Preview panel: its title, which shows its code, and
/// its latest frame, which takes clicks, drags and scrolls as the widget
/// would; when the code doesn't set the preview's size, a button writing
/// the size it rendered at.
class PreviewCard extends ConsumerWidget {
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

  /// Writes the preview's rendered size in its annotation; null when its
  /// size is set or can't be written there.
  final VoidCallback? onFixSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onTap: () => openFileAtLine(ref, path, item.line),
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
              if (onFixSize case final fix? when frame != null)
                CompactIconButton(
                  icon: Icons.straighten,
                  tooltip: _fixSizeTooltip(frame),
                  onPressed: fix,
                ),
            ],
          ),
          if (frame == null)
            const InlineSpinner()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildFrame(ref, frame.size * zoom, frame.png),
            ),
        ],
      ),
    );
  }

  /// Why [frame]'s size isn't set by the code, and what fixing it writes.
  static String _fixSizeTooltip(PreviewFrame frame) {
    final reasons = [
      if (frame.widthFollowsPanel) 'its width follows the panel',
      if (frame.heightIsFallback) 'its height is a default',
    ].join(' and ');
    return 'Fix Size in Code: $reasons; writes '
        '${PreviewSizeFixer.sizeArgumentFor(frame.size)}';
  }

  /// The frame's image at [size], forwarding the pointer to the preview.
  Widget _buildFrame(WidgetRef ref, Size size, Uint8List png) {
    final controller = ref.read(previewControllerProvider.notifier);
    void send(PreviewPointerPhase phase, Offset position, [Offset? scroll]) =>
        controller.pointer(
          index,
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
      child: Image.memory(
        png,
        width: size.width,
        height: size.height,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
