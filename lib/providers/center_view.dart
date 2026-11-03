import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

/// A full view the center panel shows instead of the editor or the project
/// overview.
enum CenterView {
  /// The review of the project's app icons.
  appIcons('App Icons'),

  /// The interactive graph of the project's architecture layers.
  architecture('Architecture');

  const CenterView(this.label);

  /// The view's name, as the View menu lists it.
  final String label;
}

/// The view the center panel shows instead of the editor or the project
/// overview; null for neither.
final centerViewProvider = StateProvider<CenterView?>((_ /*ref*/) => null);

/// A file opened in the editor from a center [view], as an absolute
/// [path]: closing the file returns to the view.
typedef CenterViewFile = ({CenterView view, String path});

/// The file opened in the editor from a center view; null when the editor
/// shows anything else. Forgotten when the project changes.
final centerViewOpenedFileProvider = StateProvider<CenterViewFile?>((ref) {
  ref.watch(currentProjectPathProvider);
  return null;
});
