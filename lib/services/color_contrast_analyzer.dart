import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/color_contrast_report.dart';
import 'package:fide/models/color_roles.dart';
import 'package:fide/models/material_palette.dart';
import 'package:fide/models/wcag_color.dart';
import 'package:path/path.dart' as p;

part 'color_contrast_analyzer.backdrop.dart';
part 'color_contrast_analyzer.call.dart';
part 'color_contrast_analyzer.color_evaluator.dart';
part 'color_contrast_analyzer.color_use_collector.dart';
part 'color_contrast_analyzer.contrast_visitor.dart';
part 'color_contrast_analyzer.declaration_collector.dart';
part 'color_contrast_analyzer.fill.dart';
part 'color_contrast_analyzer.project_theme.dart';
part 'color_contrast_analyzer.scheme_definition.dart';
part 'color_contrast_analyzer.source_file.dart';

/// Finds the colors of a Flutter project that fall below WCAG 2 level AA,
/// reading the Dart code of its `lib` folder without resolving it, as
/// fCheck's analyzers do:
///
/// - the on-colors of each `ColorScheme` it defines against their fills;
/// - each text and icon color against what it is drawn on: the fill of
///   the nearest widget around it that paints one (its color, its
///   decoration, its `backgroundColor`, or the Material 3 default of a
///   Scaffold, a Card, a Dialog…), in each theme the app renders;
/// - and, with no such widget around it, against the surface, where only
///   what the theme or an opacity causes counts: a fixed color unreadable
///   in the dark theme, or one an opacity fades.
///
/// It judges only colors it can read: literals, Material's `Colors`, the
/// project's constants and its color scheme's roles; a color or a
/// background it can't read is skipped, never guessed. Code is skipped,
/// as in fCheck, when the line it starts on ends with
/// `// ignore: fcheck_color_contrast`, and a whole file when that comment
/// is among the comments it starts with.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class ColorContrastAnalyzer {
  /// Creates a stateless analyzer.
  const ColorContrastAnalyzer();

  /// The name an `// ignore:` comment gives to skip the analyzer, in
  /// fCheck's naming.
  static const String ignoreName = 'fcheck_color_contrast';

  /// Most characters of code a finding quotes.
  static const int _maxShownChars = 60;

  /// Reads the `lib` folder of the project at [projectPath]; synchronous,
  /// so run it off the UI thread.
  ColorContrastReport analyze(String projectPath) {
    final files = _SourceFile.readAll(p.join(projectPath, 'lib'));
    final theme = _ProjectTheme.collect(files);
    final judged = [
      for (final file in files) _ContrastVisitor.judge(file, theme),
    ];
    final uses = _ColorUseCollector(theme);
    for (final file in files) {
      uses.collect(file);
    }
    final seen = <String>{};
    final checks = [
      ...theme.pairChecks(),
      for (final file in judged) ...file.checks,
    ].where((check) => seen.add(_keyOf(check))).toList();
    checks.sort(
      (a, b) => a.path == b.path
          ? a.line.compareTo(b.line)
          : a.path.compareTo(b.path),
    );
    return ColorContrastReport(
      checks: checks,
      fileCount: files.length,
      unjudged: judged.fold(0, (sum, file) => sum + file.unjudged),
      colors: uses.usages,
      schemes: theme.schemes,
    );
  }

  /// What makes [check] a repeat of another, such as a scheme pair its
  /// copy judges again: its place and message.
  static String _keyOf(ColorContrastCheck check) =>
      '${check.path}:${check.line}:${check.message}';

  /// The code of [node] as a finding quotes it, cut at [_maxShownChars].
  static String _shown(AstNode node) {
    final source = node.toSource();
    return source.length <= _maxShownChars
        ? source
        : '${source.substring(0, _maxShownChars - 1)}…';
  }
}
