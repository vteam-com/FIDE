import 'package:fide/models/search_result.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/quick_fix_providers.dart';
import 'package:fide/services/outline_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [OutlineParser] for a file path's type, or null when its type has
/// no outline; override in tests to outline other types. Disposed once
/// unused, so it doesn't keep an entry for every path ever outlined.
final outlineParserProvider = Provider.autoDispose
    .family<OutlineParser?, String>(
      (_, filePath) => OutlineParser.forFile(filePath),
    );

/// What the function or method declared at a 1-based line and column of a
/// file calls in the project, as `ReferenceFinder.callees` finds it; found
/// again as files are saved, and empty without an open project.
final calleesProvider = FutureProvider.autoDispose
    .family<List<SearchResult>, ({String path, int line, int column})>((
      ref,
      at,
    ) {
      ref.watch(savedFilesRevisionProvider);
      final finder = ref.watch(referenceFinderProvider);
      if (finder == null) return const [];
      return finder.callees(
        filePath: at.path,
        line: at.line,
        column: at.column,
      );
    });
