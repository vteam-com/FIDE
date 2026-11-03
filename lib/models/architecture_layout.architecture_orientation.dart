part of 'architecture_layout.dart';

/// Which way the architecture graph stacks its layers.
enum ArchitectureOrientation {
  /// Layers as rows, top down like the layers of a cake: the entry points
  /// on top, the files everything builds on at the bottom.
  topDown,

  /// Layers as columns, left to right: the entry points on the left.
  leftToRight,
}
