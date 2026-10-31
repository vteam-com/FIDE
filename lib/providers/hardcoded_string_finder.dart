import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/hardcoded_string.dart';
import 'package:path/path.dart' as p;

/// Finds the hardcoded strings fCheck located that can still be rewritten
/// where they are, for the quick fixes that rewrite them.
class HardcodedStringFinder {
  const HardcodedStringFinder._();

  /// Reason for strings fCheck found without parsing their file.
  static const String unparsed = 'in files that do not parse';

  /// Reason for strings in `part of` files, which cannot import.
  static const String partFile = 'in part files';

  /// Reason for strings whose file changed since fCheck read it.
  static const String changedFile = 'in files changed since the analysis';

  /// Reason for strings the user did not select.
  static const String unchecked = 'left unchecked';

  /// A `part of` directive; part files cannot add imports.
  static final RegExp _partOf = RegExp(r'^\s*part\s+of\b', multiLine: true);

  /// The strings in [metrics] that can be rewritten, in file order, the
  /// others located with their reason when parsed, and all others counted
  /// by reason; [reject] names a fix's own reason to leave a string, or
  /// returns null to keep it.
  static Future<
    ({
      List<HardcodedString> candidates,
      Map<HardcodedString, String> rejected,
      Map<String, int> skipped,
    })
  >
  find(
    fcheck.ProjectMetrics metrics, {
    required String? Function(HardcodedString) reject,
  }) async {
    final skipped = <String, int>{};
    final sitesByFile = <String, Map<int, (int, fcheck.HardcodedStringSite)>>{};
    for (final issue in metrics.hardcodedStringIssues) {
      final site = issue.site;
      if (site == null) {
        count(skipped, unparsed);
        continue;
      }
      final path = p.normalize(
        p.join(metrics.analysisRootPath, issue.filePath),
      );
      // Adjacent strings share one site
      (sitesByFile[path] ??= {})[site.offset] = (issue.lineNumber, site);
    }

    final candidates = <HardcodedString>[];
    final rejected = <HardcodedString, String>{};
    for (final MapEntry(key: path, value: sites) in sitesByFile.entries) {
      final content = await File(path).readAsString();
      final isPartFile = _partOf.hasMatch(content);
      for (final (line, site) in sites.values) {
        final string = HardcodedString(path: path, line: line, site: site);
        final reason = isPartFile
            ? partFile
            : !isStringAt(content, site)
            ? changedFile
            : reject(string);
        if (reason == null) {
          candidates.add(string);
        } else {
          rejected[string] = reason;
          count(skipped, reason);
        }
      }
    }
    return (candidates: candidates, rejected: rejected, skipped: skipped);
  }

  /// Adds [amount] to [reason] in [skipped].
  static void count(Map<String, int> skipped, String reason, [int amount = 1]) {
    skipped.update(reason, (sum) => sum + amount, ifAbsent: () => amount);
  }

  /// Whether [content] still holds a string literal where [site] says.
  static bool isStringAt(String content, fcheck.HardcodedStringSite site) {
    final end = site.offset + site.length;
    if (end > content.length) return false;
    return RegExp(r'''^r?['"][\s\S]*['"]$''')
        .hasMatch(content.substring(site.offset, end));
  }
}
