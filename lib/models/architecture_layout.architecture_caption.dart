part of 'architecture_layout.dart';

/// A caption of the architecture graph: a layer's, atop its column, or a
/// folder's, above its files.
class ArchitectureCaption {
  /// Smaller text after [text], such as a layer's file count; none when
  /// null.
  final String? detail;

  /// Whether the caption heads a layer's column rather than a folder.
  final bool isLayer;

  /// Where the caption is drawn.
  final Rect rect;

  /// The layer or folder name.
  final String text;

  /// Creates the caption [text] drawn in [rect].
  const ArchitectureCaption({
    required this.text,
    required this.rect,
    this.detail,
    this.isLayer = false,
  });
}
