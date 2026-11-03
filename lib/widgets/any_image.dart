import 'dart:io';
import 'dart:typed_data';

import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An image of any supported format, vector (SVG) or raster, fitted inside
/// its box; a decoding failure shows an error state instead.
class AnyImage extends StatelessWidget {
  /// Creates the image read from the file at [path].
  AnyImage.file(String path, {super.key})
    : bytes = null,
      file = File(path),
      isVector = _isVector(path);

  /// Creates the image decoded from [bytes], of the format [path] names.
  AnyImage.memory(Uint8List this.bytes, {super.key, required String path})
    : file = null,
      isVector = _isVector(path);

  /// Extension of vector images, drawn by `flutter_svg`.
  static const String _svgExtension = 'svg';

  /// The encoded image; null when read from [file].
  final Uint8List? bytes;

  /// The image file; null when decoded from [bytes].
  final File? file;

  /// Whether the image is an SVG rather than a raster.
  final bool isVector;
  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    final file = this.file;
    if (isVector) {
      return bytes != null
          ? SvgPicture.memory(bytes, fit: BoxFit.contain, errorBuilder: _error)
          : SvgPicture.file(file!, fit: BoxFit.contain, errorBuilder: _error);
    }
    return bytes != null
        ? Image.memory(bytes, fit: BoxFit.contain, errorBuilder: _error)
        : Image.file(file!, fit: BoxFit.contain, errorBuilder: _error);
  }

  /// Shown in place of an image that can't be decoded.
  Widget _error(BuildContext _, Object _, StackTrace? _) {
    return const EmptyState.error(
      title: 'Failed to load image',
      message: 'The image file may be corrupted or unsupported',
    );
  }

  /// Whether the file at [path] is an SVG.
  static bool _isVector(String path) =>
      FileTypeUtils.extensionOf(path) == _svgExtension;
}
