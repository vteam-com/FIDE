import 'package:code_forge/code_forge.dart';

/// Folds or unfolds every region of a [CodeForgeController] at once.
extension CodeFolding on CodeForgeController {
  /// Unfolds every region when [expanded], else folds every outermost one.
  ///
  /// Throws a [StateError] when the editor offers no folding.
  void setAllRegionsExpanded(bool expanded) {
    if (expanded) {
      unfoldAll();
    } else {
      _foldTopLevelRegions();
    }
  }

  /// Folds every outermost foldable region, leaving nested regions inside.
  ///
  /// Replaces `CodeForgeController.foldAll`, which crashes in code_forge
  /// 11.4.0 on a null check whenever a scanned line has no fold range.
  void _foldTopLevelRegions() {
    var line = 0;
    while (line < lineCount) {
      final existing = foldings[line];
      if (existing == null || !existing.isFolded) {
        toggleFold(line);
      }
      final fold = foldings[line];
      line = fold != null && fold.isFolded ? fold.endIndex + 1 : line + 1;
    }
  }
}
