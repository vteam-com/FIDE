import 'package:fide/models/image_backdrop.dart';
import 'package:flutter/material.dart';

/// The glyph of an [ImageBackdrop] in the backdrop picker.
extension ImageBackdropIcon on ImageBackdrop {
  /// Glyph shown in the backdrop picker.
  IconData get icon => switch (this) {
    ImageBackdrop.transparent => Icons.grid_on,
    ImageBackdrop.black => Icons.square,
    ImageBackdrop.white => Icons.square_outlined,
    ImageBackdrop.rainbow => Icons.gradient,
  };
}
