import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/models/image_backdrop.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/image_backdrop_box.dart';
import 'package:fide/widgets/image_backdrop_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  /// Extension of vector images, drawn by `flutter_svg`.
  static const String _svgExtension = 'svg';

  @override
  void initState() {
    super.initState();
    _fileLength = File(widget.filePath).length();
    _transformation.addListener(_onTransformationChanged);
  }

  @override
  void didUpdateWidget(EditorScreenImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _fileLength = File(widget.filePath).length();
      _resetScale();
    }
  }

  @override
  void dispose() {
    _transformation
      ..removeListener(_onTransformationChanged)
      ..dispose();
    super.dispose();
  }

  /// The zoom of the image, [AppZoom.actualSize] when unscaled.
  double get _scale => _transformation.value.getMaxScaleOnAxis();

  /// Repaints the strip's zoom percent.
  void _onTransformationChanged() => setState(() {});

  /// Shows the image unscaled and unpanned.
  void _resetScale() => _transformation.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final filePath = widget.filePath;
    final extension = FileTypeUtils.extensionOf(filePath);
    final file = File(filePath);
    final screen = MediaQuery.sizeOf(context);
    final backdrop = ref.watch(imageBackdropProvider);
    return Column(
      children: [
        HeaderBar(
          child: Row(
            spacing: AppSpacing.medium,
            children: [
              ChoiceButtons(
                values: ImageBackdrop.values,
                selected: backdrop,
                icon: (backdrop) => backdrop.icon,
                label: (backdrop) => backdrop.label,
                onSelected: (backdrop) =>
                    ref.read(imageBackdropProvider.notifier).state = backdrop,
              ),
              const Spacer(),
              Tooltip(
                message: 'Actual Size',
                child: CompactTextButton(
                  label: AppZoom.label(_scale),
                  onPressed: _scale == AppZoom.actualSize ? null : _resetScale,
                ),
              ),
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
          child: InteractiveViewer(
            transformationController: _transformation,
            minScale: EditorConfig.imagePreviewMinScale,
            maxScale: EditorConfig.imagePreviewMaxScale,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth:
                        screen.width * EditorConfig.imagePreviewMaxWidthFactor,
                    maxHeight:
                        screen.height *
                        EditorConfig.imagePreviewMaxHeightFactor,
                  ),
                  child: ImageBackdropBox(
                    backdrop: backdrop,
                    child: extension == _svgExtension
                        ? SvgPicture.file(
                            file,
                            fit: BoxFit.contain,
                            errorBuilder: (
                              _,
                              _ /* error */,
                              _ /* stackTrace */,
                            ) => _buildError(),
                          )
                        : Image.file(
                            file,
                            fit: BoxFit.contain,
                            errorBuilder: (
                              _,
                              _ /* error */,
                              _ /* stackTrace */,
                            ) => _buildError(),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shown in place of an image that can't be decoded.
  Widget _buildError() {
    return const EmptyState.error(
      title: 'Failed to load image',
      message: 'The image file may be corrupted or unsupported',
    );
  }
}
