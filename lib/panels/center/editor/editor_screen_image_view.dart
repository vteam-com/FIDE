import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/any_image.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/image_backdrop_buttons.dart';
import 'package:fide/widgets/image_canvas.dart';
import 'package:fide/widgets/image_zoom_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  /// Size of [EditorScreenImageView.filePath] on disk, read once per file.
  late Future<int> _fileLength;

  /// Zoom and pan of the image, pinched and dragged by the user.
  final TransformationController _transformation = TransformationController();

  @override
  void initState() {
    super.initState();
    _fileLength = File(widget.filePath).length();
  }

  @override
  void didUpdateWidget(EditorScreenImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _fileLength = File(widget.filePath).length();
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
    final extension = FileTypeUtils.extensionOf(filePath);
    return Column(
      children: [
        HeaderBar(
          child: Row(
            spacing: AppSpacing.medium,
            children: [
              const ImageBackdropButtons(),
              const Spacer(),
              ImageZoomLabel(controller: _transformation),
              FutureBuilder<int>(
                future: _fileLength,
                builder: (context, snapshot) => Text(
                  [
                    ?snapshot.data?.readableSize,
                    extension.toUpperCase(),
                  ].join(' • '),
                  style: AppTextStyle.secondary(context),
                ),
              ),
            ],
          ),
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
