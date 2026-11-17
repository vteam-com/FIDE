import 'package:fide/services/outline_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [OutlineParser] for a file path's type, or null when its type has
/// no outline; override in tests to outline other types. Disposed once
/// unused, so it doesn't keep an entry for every path ever outlined.
final outlineParserProvider = Provider.autoDispose
    .family<OutlineParser?, String>(
      (_, filePath) => OutlineParser.forFile(filePath),
    );
