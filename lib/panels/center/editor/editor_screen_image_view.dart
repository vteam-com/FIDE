import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the editor image preview for supported image files, SVG
/// included, with the file's size and format.
class EditorScreenImageView extends StatefulWidget {
  /// Creates the editor image preview.
  const EditorScreenImageView({super.key, required this.filePath});

  /// The image shown.
  final String filePath;

  @override
  State<EditorScreenImageView> createState() => _EditorScreenImageViewState();
}

class _EditorScreenImageViewState extends State<EditorScreenImageView> {
  /// Size of [EditorScreenImageView.filePath] on disk, read once per file.
  late Future<int> _fileLength;

  /// Extension of vector images, drawn by `flutter_svg`.
  static const String _svgExtension = 'svg';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final filePath = widget.filePath;
    final extension = FileTypeUtils.extensionOf(filePath);
    final file = File(filePath);
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth:
                    screen.width * EditorConfig.imagePreviewMaxWidthFactor,
                maxHeight:
                    screen.height * EditorConfig.imagePreviewMaxHeightFactor,
              ),
              child: extension == _svgExtension
                  ? SvgPicture.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _ /* error */, _ /* stackTrace */) =>
                          _buildError(),
                    )
                  : Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _ /* error */, _ /* stackTrace */) =>
                          _buildError(),
                    ),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            SurfaceCard(
              child: Column(
                children: [
                  const SectionTitle('Image Preview'),
                  const SizedBox(height: AppSpacing.tiny),
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
          ],
        ),
      ),
    );
  }

  /// Shown in place of an image that can't be decoded.
  Widget _buildError() {
    return const EmptyState(
      icon: Icons.broken_image,
      isError: true,
      title: 'Failed to load image',
      message: 'The image file may be corrupted or unsupported',
    );
  }
}
