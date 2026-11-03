import 'dart:math' as math;
import 'dart:ui';

import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/locale_number.dart';

part 'architecture_layout.architecture_caption.dart';
part 'architecture_layout.architecture_orientation.dart';

/// Where the architecture view draws each file of [graph], its layers
/// stacked one after the other in [orientation], from the entry points to
/// the files everything builds on, each headed by its layer's caption.
///
/// Inside a layer, files are grouped by folder under the folder's caption:
/// one under the other in a column ([ArchitectureOrientation.leftToRight]),
/// or side by side in blocks of at most [folderBlockRows] rows in a band
/// ([ArchitectureOrientation.topDown]).
class ArchitectureLayout {
  /// Room between two folders' blocks side by side in a band.
  static const double folderBlockGap = 24;

  /// Most files a folder's block stacks before starting another column.
  static const int folderBlockRows = 6;

  /// Height of a folder's caption above its files.
  static const double folderCaptionHeight = 24;

  /// Room between the last file of a folder and the next folder's caption
  /// in a column.
  static const double folderGap = 12;

  /// Height of a layer's caption atop it.
  static const double layerCaptionHeight = 36;

  /// Room between two layers, where the imports run.
  static const double layerGap = 160;

  /// Room around the whole graph.
  static const double margin = 32;

  /// Room between two files of a folder.
  static const double nodeGap = 4;

  /// Height of a file's box.
  static const double nodeHeight = 26;

  /// Width of a file's box; longer names are cut short.
  static const double nodeWidth = 240;

  /// The layer and folder captions.
  final List<ArchitectureCaption> captions;

  /// The files laid out.
  final ArchitectureGraph graph;

  /// The box of each file.
  final Map<String, Rect> nodes;

  /// Which way the layers are stacked.
  final ArchitectureOrientation orientation;

  /// The size of the whole graph, margins included.
  final Size size;

  /// Lays out [graph], its layers stacked in [orientation].
  factory ArchitectureLayout(
    ArchitectureGraph graph, {
    ArchitectureOrientation orientation = ArchitectureOrientation.topDown,
  }) {
    final isTopDown = orientation == ArchitectureOrientation.topDown;
    final captions = <ArchitectureCaption>[];
    final nodes = <String, Rect>{};
    // Where the next layer starts along the stacking, and how far across
    // the widest one reaches
    var next = margin;
    var across = 0.0;
    for (final layer in graph.layerNumbers) {
      final folders = <String, List<String>>{};
      for (final file in graph.files) {
        if (graph.layers[file] != layer) continue;
        folders.putIfAbsent(graph.folderOf(file), () => []).add(file);
      }
      final origin = isTopDown ? Offset(margin, next) : Offset(next, margin);
      final fileCount = folders.values.fold(0, (sum, f) => sum + f.length);
      captions.add(
        ArchitectureCaption(
          text: graph.isLayered ? 'Layer $layer' : 'Unlayered',
          detail: fileCount.count('file'),
          rect: origin & const Size(nodeWidth, layerCaptionHeight),
          isLayer: true,
        ),
      );
      final body = origin.translate(0, layerCaptionHeight);
      final bodySize = isTopDown
          ? _placeBand(folders, body, nodes, captions)
          : _placeColumn(folders, body, nodes, captions);
      final width = math.max(nodeWidth, bodySize.width);
      final height = layerCaptionHeight + bodySize.height;
      next += (isTopDown ? height : width) + layerGap;
      across = math.max(across, isTopDown ? width : height);
    }
    final along = graph.layerNumbers.isEmpty
        ? margin + margin
        : next - layerGap + margin;
    final acrossWithMargins = margin + across + margin;
    return ArchitectureLayout._(
      graph: graph,
      orientation: orientation,
      nodes: nodes,
      captions: captions,
      size: isTopDown
          ? Size(acrossWithMargins, along)
          : Size(along, acrossWithMargins),
    );
  }

  const ArchitectureLayout._({
    required this.graph,
    required this.orientation,
    required this.nodes,
    required this.captions,
    required this.size,
  });

  /// Places one layer's [folders] side by side from [origin], each its
  /// caption over its files in columns of at most [folderBlockRows];
  /// returns the size they take.
  static Size _placeBand(
    Map<String, List<String>> folders,
    Offset origin,
    Map<String, Rect> nodes,
    List<ArchitectureCaption> captions,
  ) {
    var left = origin.dx;
    var height = 0.0;
    for (final (index, MapEntry(key: folder, value: files))
        in folders.entries.indexed) {
      if (index > 0) left += folderBlockGap;
      final columns = (files.length / folderBlockRows).ceil();
      final width = columns * (nodeWidth + nodeGap) - nodeGap;
      captions.add(
        ArchitectureCaption(
          text: folder,
          rect: Rect.fromLTWH(left, origin.dy, width, folderCaptionHeight),
        ),
      );
      for (final (row, file) in files.indexed) {
        nodes[file] = Rect.fromLTWH(
          left + row ~/ folderBlockRows * (nodeWidth + nodeGap),
          origin.dy +
              folderCaptionHeight +
              row % folderBlockRows * (nodeHeight + nodeGap),
          nodeWidth,
          nodeHeight,
        );
      }
      final rows = math.min(files.length, folderBlockRows);
      height = math.max(
        height,
        folderCaptionHeight + rows * (nodeHeight + nodeGap) - nodeGap,
      );
      left += width;
    }
    return Size(left - origin.dx, height);
  }

  /// Places one layer's [folders] one under the other from [origin], each
  /// its caption over its files; returns the size they take.
  static Size _placeColumn(
    Map<String, List<String>> folders,
    Offset origin,
    Map<String, Rect> nodes,
    List<ArchitectureCaption> captions,
  ) {
    var top = origin.dy;
    for (final (index, MapEntry(key: folder, value: files))
        in folders.entries.indexed) {
      if (index > 0) top += folderGap;
      captions.add(
        ArchitectureCaption(
          text: folder,
          rect: Rect.fromLTWH(origin.dx, top, nodeWidth, folderCaptionHeight),
        ),
      );
      top += folderCaptionHeight;
      for (final file in files) {
        nodes[file] = Rect.fromLTWH(origin.dx, top, nodeWidth, nodeHeight);
        top += nodeHeight + nodeGap;
      }
    }
    return Size(nodeWidth, top - nodeGap - origin.dy);
  }
}
