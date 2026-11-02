import 'package:fide/models/asset_kind.dart';
import 'package:flutter/material.dart';

/// The glyph of an [AssetKind]'s group in the Organized view.
extension AssetKindIcon on AssetKind {
  /// Group icon.
  IconData get icon => switch (this) {
    AssetKind.images => Icons.image_outlined,
    AssetKind.icons => Icons.interests_outlined,
    AssetKind.fonts => Icons.font_download_outlined,
    AssetKind.animations => Icons.animation,
    AssetKind.audio => Icons.audiotrack_outlined,
    AssetKind.video => Icons.movie_outlined,
    AssetKind.data => Icons.data_object,
    AssetKind.other => Icons.insert_drive_file_outlined,
  };
}
