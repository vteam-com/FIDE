import 'package:fide/models/image_diff_mode.dart';
import 'package:flutter/material.dart';

/// The glyph of an [ImageDiffMode] in the mode picker.
extension ImageDiffModeIcon on ImageDiffMode {
  /// Glyph shown in the mode picker.
  IconData get icon => switch (this) {
    ImageDiffMode.twoUp => Icons.view_column_outlined,
    ImageDiffMode.swipe => Icons.compare,
    ImageDiffMode.onion => Icons.layers_outlined,
    ImageDiffMode.difference => Icons.difference,
  };
}
