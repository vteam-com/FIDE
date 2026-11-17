import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/models/text_offsets.dart';

part 'dry_review.dry_edit.dart';
part 'dry_review.dry_finding.dart';
part 'dry_review.dry_finding_kind.dart';
part 'dry_review.dry_fix.dart';
part 'dry_review.dry_location.dart';
part 'dry_review.dry_variant.dart';

/// What the DRY Review shows for a project: the repeated widget settings
/// found across its `lib` folder, read once off the UI thread.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class DryReview {
  /// Creates a review of [widgetCount] widgets built across [fileCount]
  /// files.
  const DryReview({
    required this.findings,
    required this.widgetCount,
    required this.fileCount,
    this.takenNames = const {},
  });

  /// Every name a file of the project sees, which a widget extracted by a
  /// fix can't take.
  final Set<String> takenNames;

  /// How many Dart files were read.
  final int fileCount;

  /// What was found, most repeated first.
  final List<DryFinding> findings;

  /// How many widgets the files build.
  final int widgetCount;

  /// The findings of [kind], in order.
  List<DryFinding> of(DryFindingKind kind) => [
    for (final finding in findings)
      if (finding.kind == kind) finding,
  ];
}
