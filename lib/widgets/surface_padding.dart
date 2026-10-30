import 'package:fide/constants/constants.dart';
import 'package:flutter/widgets.dart';

/// The only insets a box (`SurfaceCard`, `OutlinedSurface`) puts around
/// its content.
enum SurfacePadding {
  /// Cards, notes and summaries.
  normal(EdgeInsets.all(AppSpacing.xLarge)),

  /// List entries and details.
  dense(EdgeInsets.all(AppSpacing.medium)),

  /// Boxes framing content that brings its own padding, such as a list or
  /// a tile.
  none(EdgeInsets.zero);

  const SurfacePadding(this.insets);

  /// The insets.
  final EdgeInsets insets;
}
