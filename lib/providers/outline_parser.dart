import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:yaml/yaml.dart';

part 'outline_parser.dart_outline_parser.dart';
part 'outline_parser.markdown_outline_parser.dart';
part 'outline_parser.outline_visitor.dart';
part 'outline_parser.yaml_outline_parser.dart';

/// Turns a file's text into its outline.
abstract class OutlineParser {
  /// Parsers by file extension.
  static const Map<String, OutlineParser> _byExtension = {
    'dart': DartOutlineParser(),
    'md': MarkdownOutlineParser(),
    'markdown': MarkdownOutlineParser(),
    'yaml': YamlOutlineParser(),
    'yml': YamlOutlineParser(),
  };

  /// Base constructor for the const parsers.
  const OutlineParser();

  /// The parser for [filePath]'s type, or null when it has no outline.
  static OutlineParser? forFile(String filePath) {
    return _byExtension[FileTypeUtils.extensionOf(filePath)];
  }

  /// The outline of [content]; throws when it can't be parsed.
  List<OutlineNode> parse(String content);
}
