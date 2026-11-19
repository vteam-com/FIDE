import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

/// [content] parsed as Dart in the latest language version, keeping what
/// parses when the code has errors, as code being edited often does.
ParseStringResult parseDart(String content) =>
    parseString(content: content, throwIfDiagnostics: false);
