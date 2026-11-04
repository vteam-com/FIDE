import 'package:flutter/material.dart';

/// Which previews the Preview panel lists; each value's `name` is how the
/// choice is saved.
enum PreviewScope {
  /// Every preview of the file selected, all rendered.
  file('Current File', Icons.description_outlined),

  /// Every preview of the project, collapsed, the one expanded rendered.
  project('Project', Icons.account_tree_outlined);

  const PreviewScope(this.label, this.icon);

  /// The choice's tooltip.
  final String label;

  /// The choice's icon.
  final IconData icon;
}
