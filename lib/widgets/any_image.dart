import 'dart:io';
import 'dart:typed_data';

import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/any_image.styled_svg_loader.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/pixel_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// An image of any supported format, vector (SVG) or raster, fitted inside
/// its box; a decoding failure shows an error state instead.
class AnyImage extends StatelessWidget {
  /// Creates the image read from the file at [path].
  AnyImage.file(String path, {super.key})
    : bytes = null,
      file = File(path),
      isVector = FileTypeUtils.isSvg(path);

  /// Creates the image decoded from [bytes], of the format [path] names.
  AnyImage.memory(Uint8List this.bytes, {super.key, required String path})
    : file = null,
      isVector = FileTypeUtils.isSvg(path);

  /// The encoded image; null when read from [file].
  final Uint8List? bytes;

  /// The image file; null when decoded from [bytes].
  final File? file;

  /// Whether the image is an SVG rather than a raster, drawn by
  /// `flutter_svg` once its style sheet is inlined by [StyledSvgLoader].
  final bool isVector;
  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    final file = this.file;
    if (isVector) {
      return SvgPicture(
        bytes != null
            ? StyledSvgLoader.memory(bytes)
            : StyledSvgLoader.file(file!),
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => _error(context),
      );
    }
    return PixelImage(
      bytes != null ? MemoryImage(bytes) : FileImage(file!),
      errorBuilder: _error,
    );
  }

  /// Shown in place of an image that can't be decoded.
  Widget _error(BuildContext _) {
    return const EmptyState.error(
      title: 'Failed to load image',
      message: 'The image file may be corrupted or unsupported',
    );
  }
}
