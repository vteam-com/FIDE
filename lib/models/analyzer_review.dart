import 'package:material_ui/material_ui.dart';

/// The reviews the Analyzer tab shows, one at a time; each value's `name`
/// is how the choice is saved.
enum AnalyzerReview {
  /// The files outside the folder their kind belongs in.
  layout('File Layout', Icons.drive_file_move_outline),

  /// The widget settings the project writes more than once.
  repeated('Repeated Widget Settings', Icons.repeat);

  const AnalyzerReview(this.label, this.icon);

  /// The review's name, atop the tab and as its choice's tooltip.
  final String label;

  /// The review's choice's icon.
  final IconData icon;
}
