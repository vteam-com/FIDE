import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

/// A full view the center panel shows instead of the editor.
enum CenterView {
  /// The project's overview and quality, shown even while files are open.
  overview('Project Overview'),

  /// The review of the project's app icons.
  appIcons('App Icons'),

  /// The interactive graph of the project's architecture layers.
  architecture('Architecture'),

  /// The review of how accessible the project's colors are.
  accessibility('Accessibility');

  const CenterView(this.label);

  /// The view's name, as the View menu lists it.
  final String label;
}

/// The view the center panel shows instead of the editor; null for the
/// editor, or the project overview when no file is open.
final centerViewProvider = StateProvider<CenterView?>((_ /*ref*/) => null);

/// A file opened in the editor from a center [view], as an absolute
/// [path]: closing the file returns to the view.
typedef CenterViewFile = ({CenterView view, String path});

/// Where the center panel goes when the editor's active file changes
/// from [previous] to [next] (absolute paths, null for none) while it
/// shows [showing] and remembers [opened]: opening or switching files
/// leaves the center view, and closing a file opened from one goes back
/// to it.
({CenterView? view, CenterViewFile? opened}) centerViewAfterFileChange({
  required String? previous,
  required String? next,
  required CenterView? showing,
  required CenterViewFile? opened,
}) {
  final closedOpened = next == null && previous != null;
  final returnTo = closedOpened && previous == opened?.path
      ? opened?.view
      : null;
  return (
    view: returnTo,
    opened: switch (showing) {
      final showing? => next == null ? null : (view: showing, path: next),
      null when returnTo != null || next != opened?.path => null,
      null => opened,
    },
  );
}

/// The file opened in the editor from a center view; null when the editor
/// shows anything else. Forgotten when the project changes.
final centerViewOpenedFileProvider = StateProvider<CenterViewFile?>((ref) {
  ref.watch(currentProjectPathProvider);
  return null;
});
