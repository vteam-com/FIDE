import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
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
    this.quickFixes = const [],
    this.aiVerb = 'Fix',
  });

  /// What the AI agent does to the findings, such as `Localize`; it starts
  /// the AI action's label ([aiActionLabel]) and its request
  /// ([fixRequest]); null when the issue offers no agent request.
  final String? aiVerb;

  /// Where the issue was found, in order.
  final List<QualityFinding> findings;

  /// The best practice that fixes the issue, as Markdown; none when null.
  final String? guidance;

  /// What is wrong, with its count or score impact.
  final String label;

  /// The fixes FIDE applies itself, without AI.
  final List<QuickFix> quickFixes;

  /// The project folder [findings] are listed relative to.
  final String? rootPath;

  /// How serious the issue is.
  final StatusTone tone;

  /// The request asking the AI to fix every finding by editing the
  /// project files, following [guidance]; null when there is nothing in
  /// the code to fix.
  String? get fixRequest {
    if (findings.isEmpty || aiVerb == null) return null;
    final request = StringBuffer(
      '$aiVerb these "$label" findings by editing the project files.\n',
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

  /// The label of the action sending [fixRequest], such as
  /// `Localize with AI`.
  String? get aiActionLabel => aiVerb == null ? null : '$aiVerb with AI';

  /// Whether there is more to show than [label]: guidance, findings or
  /// quick fixes.
  bool get hasDetails =>
      guidance != null || findings.isNotEmpty || quickFixes.isNotEmpty;

  /// The path of [finding], relative to [rootPath] when given.
  String shownPath(QualityFinding finding) {
    final root = rootPath;
    return root == null ? finding.path : p.relative(finding.path, from: root);
  }
}
