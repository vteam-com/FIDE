part of 'side_by_side_diff.dart';

/// Represents `DiffLine`.
class DiffLine {
  final String oldLine;
  final String oldContent;
  final String newLine;
  final String newContent;
  final DiffType type;

  DiffLine({
    required this.oldLine,
    required this.oldContent,
    required this.newLine,
    required this.newContent,
    required this.type,
  });
}
