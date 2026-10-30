import 'package:fide/constants/constants.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:path/path.dart' as p;

/// A problem lowering the project's quality, shown the same way wherever
/// it appears: what is wrong, the best practice that fixes it, where it
/// was found, and the request that lets the AI fix it.
class QualityIssue {
  /// Creates the issue named [label].
  const QualityIssue({
    required this.label,
    this.tone = StatusTone.warning,
    this.guidance,
    this.findings = const [],
    this.rootPath,
  });

  /// Where the issue was found, in order.
  final List<QualityFinding> findings;

  /// The best practice that fixes the issue, as Markdown; none when null.
  final String? guidance;

  /// What is wrong, with its count or score impact.
  final String label;

  /// The project folder [findings] are listed relative to.
  final String? rootPath;

  /// How serious the issue is.
  final StatusTone tone;

  /// The request asking the AI to fix every finding by editing the
  /// project files, following [guidance]; null when there is nothing in
  /// the code to fix.
  String? get fixRequest {
    if (findings.isEmpty) return null;
    final request = StringBuffer(
      'Fix these "$label" findings by editing the project files.\n',
    );
    if (guidance case final guidance?) {
      request.writeln('Follow this best practice:\n$guidance');
    }
    request.writeln();
    for (final finding in findings) {
      request.writeln(
        '- ${shownPath(finding)}:${finding.line}: ${finding.text}',
      );
    }
    return request.toString().truncated(AppMetric.aiReviewContextChars);
  }

  /// Whether there is more to show than [label]: guidance or findings.
  bool get hasDetails => guidance != null || findings.isNotEmpty;

  /// The path of [finding], relative to [rootPath] when given.
  String shownPath(QualityFinding finding) {
    final root = rootPath;
    return root == null ? finding.path : p.relative(finding.path, from: root);
  }
}
