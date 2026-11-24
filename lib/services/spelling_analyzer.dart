import 'dart:io';

import 'package:fide/models/project_files.dart';
import 'package:fide/models/spelling_finding.dart';
import 'package:fide/models/spelling_report.dart';
import 'package:fide/services/parsed_source_file.dart';
import 'package:fide/services/spelling_checker.dart';
import 'package:list_english_words/list_english_words.dart';
import 'package:path/path.dart' as p;

/// Checks the spelling of a project's Dart code in `lib` and `test`: the
/// words of its names, comments and strings that no English or programming
/// word matches, nor a word listed in the project's `.fide-words` file.
///
/// Reads the files synchronously, so run it with `Isolate.run`.
class SpellingAnalyzer {
  /// Name of the project file listing words the check accepts, one per
  /// line, `#` starting a comment.
  static const String allowlistName = '.fide-words';

  /// Folders of the project whose Dart files are checked.
  static const List<String> checkedFolders = ['lib', 'test'];

  /// Creates the analyzer.
  const SpellingAnalyzer();

  /// The spelling report of the project at [projectPath].
  SpellingReport analyze(String projectPath) {
    final checker = SpellingChecker({
      ...list_english_words,
      ...SpellingChecker.programmingTerms,
      ..._allowed(projectPath),
    });
    var checked = 0;
    final words = <String>{};
    final findings = <SpellingFinding>[];
    for (final path in checkedFiles(projectPath)) {
      final result = checker.check(path, File(path).readAsStringSync());
      checked += result.checked;
      words.addAll(result.words);
      findings.addAll(result.findings);
    }
    return SpellingReport(
      rootPath: projectPath,
      wordsChecked: checked,
      distinctWords: words.length,
      findings: findings,
    );
  }

  /// Adds [word] to the project's allowlist file, creating it when missing,
  /// so the spelling check accepts it from now on; a word already listed is
  /// left as it is.
  static void allow(String projectPath, String word) {
    final file = File(p.join(projectPath, allowlistName));
    final lines = file.existsSync() ? file.readAsLinesSync() : <String>[];
    final listed = lines.any((line) => line.trim().toLowerCase() == word);
    if (listed) return;
    file.writeAsStringSync('${[...lines, word].join('\n')}\n');
  }

  /// The words of the project's allowlist file, lowercase.
  static Set<String> _allowed(String projectPath) {
    final file = File(p.join(projectPath, allowlistName));
    if (!file.existsSync()) return const {};
    return {
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
          line.trim().toLowerCase(),
    };
  }

  /// The Dart files of the checked folders, leaving out generated ones and
  /// those in skipped folders.
  static List<String> checkedFiles(String projectPath) => [
    for (final folder in checkedFolders)
      if (Directory(p.join(projectPath, folder)).existsSync())
        for (final entity in Directory(
          p.join(projectPath, folder),
        ).listSync(recursive: true, followLinks: false))
          if (entity is File &&
              entity.path.endsWith(ProjectFiles.dartExtension) &&
              !_isSkipped(p.relative(entity.path, from: projectPath)) &&
              !ParsedSourceFile.generatedSuffixes.any(entity.path.endsWith) &&
              !_isGenerated(entity.path))
            entity.path,
  ];

  /// Whether the file at [path] is generated code: a localizations file,
  /// whose words are the translated languages', not English.
  static bool _isGenerated(String path) {
    final name = p.basename(path);
    return name.startsWith('app_localizations') ||
        p.split(path).contains('generated');
  }

  /// Whether any folder of the relative [path] is skipped.
  static bool _isSkipped(String path) =>
      p.split(path).any(ProjectFiles.isSkipped);
}
