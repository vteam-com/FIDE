import 'dart:math' as math;
import 'dart:ui';

import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/locale_number.dart';

part 'architecture_layout.architecture_caption.dart';

/// Where the architecture view draws each file of [graph]: one column per
/// layer, left to right from the entry points to the files everything
/// builds on, each headed by its layer's caption; inside a column, files
/// grouped by folder under the folder's caption.
class ArchitectureLayout {
  /// Height of a layer's caption atop its column.
  static const double layerCaptionHeight = 36;

  /// Height of a folder's caption above its files.
  static const double folderCaptionHeight = 24;

  /// Room between two columns, where the imports run.
  static const double columnGap = 160;

  /// Room between the last file of a folder and the next folder's caption.
  static const double folderGap = 12;

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

  /// The size of the whole graph, margins included.
  final Size size;

  /// Lays out [graph].
  factory ArchitectureLayout(ArchitectureGraph graph) {
    final captions = <ArchitectureCaption>[];
    final nodes = <String, Rect>{};
    final layerNumbers = graph.layerNumbers;
    var bottom = 0.0;
    for (final (column, layer) in layerNumbers.indexed) {
      final left = margin + column * (nodeWidth + columnGap);
      final files = [
        for (final file in graph.files)
          if (graph.layers[file] == layer) file,
      ];
      captions.add(
        ArchitectureCaption(
          text: graph.isLayered ? 'Layer $layer' : 'Unlayered',
          detail: files.length.count('file'),
          rect: Rect.fromLTWH(left, margin, nodeWidth, layerCaptionHeight),
          isLayer: true,
        ),
      );
      var top = margin + layerCaptionHeight;
      String? folder;
      for (final file in files) {
        final fileFolder = graph.folderOf(file);
        if (fileFolder != folder) {
          if (folder != null) top += folderGap;
          folder = fileFolder;
          captions.add(
            ArchitectureCaption(
              text: fileFolder,
              rect: Rect.fromLTWH(left, top, nodeWidth, folderCaptionHeight),
            ),
          );
          top += folderCaptionHeight;
        }
        nodes[file] = Rect.fromLTWH(left, top, nodeWidth, nodeHeight);
        top += nodeHeight + nodeGap;
      }
      bottom = math.max(bottom, top);
    }
    final columns = layerNumbers.length;
    return ArchitectureLayout._(
      graph: graph,
      nodes: nodes,
      captions: captions,
      size: Size(
        margin +
            columns * nodeWidth +
            math.max(0, columns - 1) * columnGap +
            margin,
        bottom + margin,
      ),
    );
  }

  const ArchitectureLayout._({
    required this.graph,
    required this.nodes,
    required this.captions,
    required this.size,
  });
}
