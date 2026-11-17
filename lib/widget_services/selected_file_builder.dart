import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Builds a file's row knowing whether that file is the selected one, and
/// rebuilds it only when that changes: selecting another file rebuilds the
/// two rows concerned, not every row of the list.
class SelectedFileBuilder extends ConsumerWidget {
  /// Creates the row of the file at [path], built by [builder].
  const SelectedFileBuilder({
    super.key,
    required this.path,
    required this.builder,
  });

  /// Builds the row, highlighted when the file is selected.
  final Widget Function(BuildContext context, bool isSelected) builder;

  /// The file the row shows.
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(
      selectedFileProvider.select(
        (file) => file != null && _samePath(file.path, path),
      ),
    );
    return builder(context, isSelected);
  }

  /// Whether [a] and [b] name the same file, however they are spelled.
  static bool _samePath(String a, String b) =>
      a == b ||
      p.normalize(a) == p.normalize(b) ||
      p.canonicalize(a) == p.canonicalize(b);
}
