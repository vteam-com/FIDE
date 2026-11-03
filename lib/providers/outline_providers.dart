import 'package:fide/services/outline_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [OutlineParser] for a file path's type, or null when its type has
/// no outline; override in tests to outline other types.
final outlineParserProvider = Provider.family<OutlineParser?, String>(
  (_, filePath) => OutlineParser.forFile(filePath),
);
