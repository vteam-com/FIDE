import 'package:fide/models/search_result.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The line of code of [result], its match marked, opening the file there:
/// a search match, a caller or a callee, a place in the code like every
/// other.
class SearchResultRow extends ConsumerWidget {
  /// Creates the row of [result].
  const SearchResultRow({super.key, required this.result, this.rootPath});

  /// The place shown.
  final SearchResult result;

  /// Project root; the tooltip shows the path relative to it when given.
  final String? rootPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = result.lineContent;
    final indent = line.length - line.trimLeft().length;
    return LocationRow(
      icon: FileIconUtils.ofPath(result.filePath),
      name: line.trim(),
      match: TextRange(
        start: result.matchStart - indent,
        end: result.matchEnd - indent,
      ),
      path: result.filePath,
      line: result.lineNumber,
      rootPath: rootPath,
      onTap: () => openPlace(ref, result),
    );
  }
}
