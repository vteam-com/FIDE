import 'package:fide/models/code_category.dart';
import 'package:material_ui/material_ui.dart';

/// The glyph of a [CodeCategory] in the Analyzer tab's reviews: the kind of
/// a file File Layout moves, and of the code a repeated widget setting is
/// in.
extension CodeCategoryIcon on CodeCategory {
  /// A view's, a model's, or a widget's for any other kind.
  IconData get icon => switch (this) {
    CodeCategory.views => Icons.web_asset,
    CodeCategory.models => Icons.data_object,
    _ => Icons.widgets_outlined,
  };
}
