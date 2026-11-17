import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/image_backdrop_buttons.dart';
import 'package:fide/widgets/any_image.dart';
import 'package:fide/widgets/file_facts_label.dart';
import 'package:fide/widgets/image_canvas.dart';
import 'package:fide/widgets/viewer_toolbar.dart';
import 'package:fide/widgets/zoom_label.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the editor image preview for supported image files, SVG
/// included, under a strip picking its background and showing the file's
/// size and format. Pinching the trackpad or turning the mouse wheel zooms
/// the image; dragging pans it; the strip's zoom percent resets it.
class EditorScreenImageView extends ConsumerStatefulWidget {
  /// Creates the editor image preview.
  const EditorScreenImageView({super.key, required this.filePath});

  /// The image shown.
  final String filePath;

  @override
  ConsumerState<EditorScreenImageView> createState() =>
      _EditorScreenImageViewState();
}

class _EditorScreenImageViewState extends ConsumerState<EditorScreenImageView> {
  /// Zoom and pan of the image, pinched and dragged by the user.
  final TransformationController _transformation = TransformationController();

  @override
  void didUpdateWidget(EditorScreenImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _transformation.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filePath = widget.filePath;
    return Column(
      children: [
        ViewerToolbar(
          leading: const [ImageBackdropButtons()],
          trailing: [
            ZoomLabel.canvas(controller: _transformation),
            FileFactsLabel(filePath: filePath),
          ],
        ),
        Expanded(
          child: ImageCanvas(
            controller: _transformation,
            backdrop: ref.watch(imageBackdropProvider),
            child: AnyImage.file(filePath),
          ),
        ),
      ],
    );
  }
}
